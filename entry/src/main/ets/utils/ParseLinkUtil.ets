import { http } from '@kit.NetworkKit';
import { Logger } from '@nzy/logger';

export async function getShareLink(content: string): Promise<string> {
  const urlRegex = /https?:\/\/[^\s\u4e00-\u9fa5]+/;
  const match = urlRegex.exec(content);
  return match ? match[0] : "";
}

export function cleanTaobaoItemUrl(url: string): string {
  const normalizedUrl = url.replace(/&amp;/g, '&').replace(/\\u0026/g, '&');
  const itemUrlMatch: RegExpExecArray | null =
    /(https?:\/\/[^'"<>\s]+\/item\.htm\?[^'"<>\s]+)/.exec(normalizedUrl);
  const itemUrl: string = itemUrlMatch && itemUrlMatch[1] ? itemUrlMatch[1] : normalizedUrl;
  const queryStartIndex: number = itemUrl.indexOf('?');
  if (queryStartIndex < 0) {
    return itemUrl;
  }

  const path: string = itemUrl.substring(0, queryStartIndex);
  const query: string = itemUrl.substring(queryStartIndex + 1);
  if (/(^|&)newBpgwSceneCode=et_item_detail(&|$)/i.test(query)) {
    const trackingStartIndex: number = query.search(/(^|&)ut_sk=/i);
    const businessQuery: string = trackingStartIndex >= 0 ? query.substring(0, trackingStartIndex) : query;
    const trimmedQuery: string = businessQuery.endsWith('&') ?
      businessQuery.substring(0, businessQuery.length - 1) : businessQuery;
    return `${path}?${trimmedQuery}`;
  }

  const idMatch: RegExpExecArray | null = /(^|&)id=([^&#]+)/.exec(query);
  if (idMatch && idMatch[2]) {
    return `${path}?id=${idMatch[2]}`;
  }

  const itemIdMatch: RegExpExecArray | null =
    /(^|&)(itemId|itemIds|shareDetailItemId)=([0-9]+)/i.exec(query);
  if (itemIdMatch && itemIdMatch[3]) {
    return `https://item.taobao.com/item.htm?id=${itemIdMatch[3]}`;
  }

  return "";
}

function isTaobaoItemUrl(url: string): boolean {
  const normalizedUrl: string = url.replace(/&amp;/g, '&').replace(/\\u0026/g, '&');
  const hostMatch: RegExpExecArray | null = /^https?:\/\/([^\/?#]+)/i.exec(normalizedUrl);
  if (!hostMatch || !hostMatch[1]) {
    return false;
  }
  const hostWithPort: string = hostMatch[1].toLowerCase();
  if (hostWithPort.includes('@')) {
    return false;
  }
  const portIndex: number = hostWithPort.indexOf(':');
  const host: string = portIndex >= 0 ? hostWithPort.substring(0, portIndex) : hostWithPort;
  const isTaobaoHost: boolean = host === 'taobao.com' || host.endsWith('.taobao.com');
  const isTmallHost: boolean = host === 'tmall.com' || host.endsWith('.tmall.com');
  if (!isTaobaoHost && !isTmallHost) {
    return false;
  }
  return /\/[^?]*item\.htm\?/i.test(normalizedUrl.substring(hostMatch[0].length));
}

export async function getFullLink(link: string): Promise<string> {
  let httpRequest: http.HttpRequest | undefined = undefined;
  try {
    if (isTaobaoItemUrl(link)) {
      return cleanTaobaoItemUrl(link);
    }

    httpRequest = http.createHttp();
    const response = await httpRequest.request(link, {
      method: http.RequestMethod.GET,
      connectTimeout: 5000,
      readTimeout: 5000,
      header: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36'
      }
    });
    if (response.responseCode === 200) {
      // 针对淘宝平台
      if (link.match("tb.cn") != null) {
        const html: string = response.result as string;
        const urlMatch: RegExpExecArray | null =
          /var\s+url\s*=\s*'([^']+)'/m.exec(html);
        if (urlMatch && urlMatch[1]) {
          const taobaoUrl: string = urlMatch[1];
          return cleanTaobaoItemUrl(taobaoUrl);
        }
      } else {
        const fullUrl: string = response.header['location'] ? response.header['location'] : "";
        return fullUrl.split('?')[0];
      }
    }
  } catch (err) {
    Logger.error(`Failed to parse full url, error message: ${err.message}`);
  } finally {
    if (httpRequest !== undefined) {
      httpRequest.destroy();
    }
  }
  return "";
}

export async function replaceOutputText(originalText: string, fullLink: string): Promise<string> {
  try {
    const urlRegex = /https?:\/\/[^\s\u4e00-\u9fa5]+/;
    const result = originalText.replace(urlRegex, (match) => {
      if (!match.startsWith('http')) {
        return match;
      }
      return fullLink;
    });
    return result;
  } catch (err) {
    Logger.error(`Failed to replace url, error message: ${err.message}`);
    return "";
  }
}

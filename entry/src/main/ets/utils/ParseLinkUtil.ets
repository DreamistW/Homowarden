import { http } from '@kit.NetworkKit';

export async function getShareLink(content: string): Promise<string> {
  const urlRegex = /https?:\/\/[^\s\u4e00-\u9fa5]+/;
  const match = urlRegex.exec(content);
  return match ? match[0] : "";
}

export async function getFullLink(link: string): Promise<string> {
  try {
    let httpRequest = http.createHttp();
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
          const idMatch: RegExpExecArray | null =
            /(https?:\/\/item\.taobao\.com\/item\.htm\?id=[^&'"]+)/.exec(taobaoUrl);

          if (idMatch && idMatch[1]) {
            const cleanUrl: string = idMatch[1];
            return cleanUrl;
          }

          // 如果正则没匹配到，就退回用原始 taobaoUrl
          return taobaoUrl;
        }
      } else {
        const fullUrl: string = response.header['location'] ? response.header['location'] : "";
        return fullUrl.split('?')[0];
      }
    }
  } catch (err) {
    console.error(`Failed to parse full url, error message: ${err.message}`);
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
    console.error(`Failed to replace url, error message: ${err.message}`);
    return "";
  }
}
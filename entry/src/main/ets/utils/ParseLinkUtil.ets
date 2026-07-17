import { http } from '@kit.NetworkKit';
import { Logger } from '@nzy/logger';

/** @returns 内容中首个 HTTP(S) 链接；不存在时返回空字符串。 */
export async function getShareLink(content: string): Promise<string> {
  const urlRegex = /https?:\/\/[^\s\u4e00-\u9fa5]+/;
  const match = urlRegex.exec(content);
  return match ? match[0] : "";
}

/**
 * 请求短链并提取重定向目标；淘宝短链从响应脚本中兼容提取商品链接。
 * @returns 成功解析且响应码为 200 时的目标链接，否则返回空字符串；网络和解析异常被吸收。
 */
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
    Logger.error(`Failed to parse full url, error message: ${err.message}`);
  }
  return "";
}

/**
 * 将原文中的首个 HTTP(S) 链接替换为展开后的链接。
 * @returns 替换后的文本；替换异常时返回空字符串。
 */
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

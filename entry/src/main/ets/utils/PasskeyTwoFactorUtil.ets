import { fido2 } from '@kit.OnlineAuthenticationKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { TwoFactorProviderData } from '../model/AccessToken';

type ProviderDataValue = Object | string | number | boolean | null | undefined;
type ProviderDataRecord = Record<string, ProviderDataValue>;

/** 将服务端二次认证参数适配为系统 FIDO2 请求并序列化认证结果。 */
export class PasskeyTwoFactorUtil {
  /**
   * 调起系统通行密钥认证。
   * @param context 用于展示系统认证界面的应用上下文。
   * @param providerData 服务端下发的 challenge、RP ID、凭据白名单及验证策略。
   * @param fallbackRpId 服务端未提供 RP ID 时使用的域名。
   * @returns 系统认证响应 JSON 对象序列化后的字符串，供令牌接口作为 2FA token 提交。
   * @throws challenge 缺失、Base64URL 解码失败或平台认证失败时传播异常。
   */
  static async authenticate(
    context: common.Context,
    providerData: TwoFactorProviderData,
    fallbackRpId: string
  ): Promise<string> {
    const options = PasskeyTwoFactorUtil.buildCredentialRequestOptions(providerData, fallbackRpId);
    const credential = await fido2.authenticate(context, options);
    return JSON.stringify(credential.authenticationResponseJson);
  }

  /** 同时兼容服务端新旧字段大小写，并将 Base64URL challenge 转换为平台要求的字节数组。 */
  private static buildCredentialRequestOptions(
    providerData: ProviderDataRecord,
    fallbackRpId: string
  ): fido2.CredentialRequestOptions {
    const challenge = PasskeyTwoFactorUtil.getString(providerData, ['challenge', 'Challenge']);
    if (!challenge) {
      throw new Error('通行密钥验证缺少 challenge');
    }

    const publicKey: fido2.PublicKeyCredentialRequestOptions = {
      challenge: PasskeyTwoFactorUtil.decodeBase64Url(challenge),
      rpId: PasskeyTwoFactorUtil.getString(providerData, ['rpId', 'RpId', 'rpID', 'Rpid']) || fallbackRpId,
      userVerification: PasskeyTwoFactorUtil.getUserVerification(providerData),
      allowCredentials: PasskeyTwoFactorUtil.getAllowCredentials(providerData),
      hints: [fido2.PublicKeyCredentialHint.CLIENT_DEVICE]
    };

    const timeout = PasskeyTwoFactorUtil.getNumber(providerData, ['timeout', 'Timeout']);
    if (timeout !== undefined) {
      publicKey.timeout = timeout;
    }

    return {
      mediation: fido2.CredentialMediationRequirement.REQUIRED,
      publicKey
    };
  }

  /** 优先读取完整凭据描述符，兼容仅下发凭据 ID 的旧响应。 */
  private static getAllowCredentials(providerData: ProviderDataRecord): Array<fido2.PublicKeyCredentialDescriptor> {
    const descriptors = PasskeyTwoFactorUtil.getValue(providerData, ['allowCredentials', 'AllowCredentials']);
    if (Array.isArray(descriptors)) {
      return descriptors
        .map((item: ProviderDataValue) => PasskeyTwoFactorUtil.parseCredentialDescriptor(item))
        .filter((item: fido2.PublicKeyCredentialDescriptor | null) => item !== null) as Array<fido2.PublicKeyCredentialDescriptor>;
    }

    const credentialIds = PasskeyTwoFactorUtil.getValue(providerData, ['credentialIds', 'CredentialIds']);
    if (Array.isArray(credentialIds)) {
      return credentialIds
        .map((item: ProviderDataValue) => PasskeyTwoFactorUtil.parseCredentialId(item))
        .filter((item: fido2.PublicKeyCredentialDescriptor | null) => item !== null) as Array<fido2.PublicKeyCredentialDescriptor>;
    }

    return [];
  }

  private static parseCredentialDescriptor(value: ProviderDataValue): fido2.PublicKeyCredentialDescriptor | null {
    if (typeof value === 'string') {
      return PasskeyTwoFactorUtil.createCredentialDescriptor(value);
    }

    if (value === null || value === undefined || typeof value !== 'object') {
      return null;
    }

    const item = value as ProviderDataRecord;
    const id = PasskeyTwoFactorUtil.getString(item, ['id', 'Id']);
    if (!id) {
      return null;
    }

    return PasskeyTwoFactorUtil.createCredentialDescriptor(id);
  }

  private static parseCredentialId(value: ProviderDataValue): fido2.PublicKeyCredentialDescriptor | null {
    if (typeof value === 'string') {
      return PasskeyTwoFactorUtil.createCredentialDescriptor(value);
    }

    return null;
  }

  private static createCredentialDescriptor(id: string): fido2.PublicKeyCredentialDescriptor {
    return {
      type: fido2.PublicKeyCredentialType.PUBLIC_KEY,
      id: PasskeyTwoFactorUtil.decodeBase64Url(id)
    };
  }

  private static getUserVerification(providerData: ProviderDataRecord): fido2.UserVerificationRequirement {
    const rawValue = PasskeyTwoFactorUtil.getString(providerData, ['userVerification', 'UserVerification']);
    switch (rawValue) {
      case fido2.UserVerificationRequirement.REQUIRED:
        return fido2.UserVerificationRequirement.REQUIRED;
      case fido2.UserVerificationRequirement.DISCOURAGED:
        return fido2.UserVerificationRequirement.DISCOURAGED;
      default:
        return fido2.UserVerificationRequirement.PREFERRED;
    }
  }

  private static getString(providerData: ProviderDataRecord, keys: string[]): string | undefined {
    const value = PasskeyTwoFactorUtil.getValue(providerData, keys);
    return typeof value === 'string' && value.length > 0 ? value : undefined;
  }

  private static getNumber(providerData: ProviderDataRecord, keys: string[]): number | undefined {
    const value = PasskeyTwoFactorUtil.getValue(providerData, keys);
    return typeof value === 'number' ? value : undefined;
  }

  private static getValue(providerData: ProviderDataRecord, keys: string[]): ProviderDataValue {
    for (let i = 0; i < keys.length; i++) {
      const value = providerData[keys[i]];
      if (value !== undefined && value !== null) {
        return value;
      }
    }

    return undefined;
  }

  /** 将无填充 Base64URL 文本转换为标准 Base64 后解码。 */
  private static decodeBase64Url(value: string): Uint8Array {
    let base64 = value.replace(/-/g, '+').replace(/_/g, '/');
    const padding = base64.length % 4;
    if (padding > 0) {
      base64 += '='.repeat(4 - padding);
    }

    return new util.Base64Helper().decodeSync(base64);
  }
}

// 关键资产管理
import { util } from '@kit.ArkTS'
import { asset } from '@kit.AssetStoreKit';
import { Logger } from '@nzy/logger';
import { BusinessError } from '@kit.BasicServicesKit';
import { AssetModel } from '../model/AssetModel';

function stringToArray(str: string): Uint8Array {
  let textEncoder = new util.TextEncoder();
  return textEncoder.encodeInto(str);
}

function arrayToString(arr: Uint8Array): string {
  let textDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
  let str = textDecoder.decodeToString(arr, { stream: false });
  return str;
}

const labelMap: Record<number, asset.Tag> = {
  0: asset.Tag.DATA_LABEL_NORMAL_1,
  1: asset.Tag.DATA_LABEL_NORMAL_2,
  2: asset.Tag.DATA_LABEL_NORMAL_3,
  3: asset.Tag.DATA_LABEL_NORMAL_4,
}

/**
 * 添加关键资产
 * @param assetModel 关键资产模型
 */
export function addAsset(assetModel: AssetModel) {
  let attr: asset.AssetMap = new Map();
  attr.set(asset.Tag.SECRET, stringToArray(assetModel.secret));
  attr.set(asset.Tag.ALIAS, stringToArray(assetModel.alias));

  // 添加附属信息
  if (assetModel.label) {
    for (let i = 0; i < assetModel.label.length; i++) {
      attr.set(labelMap[i], stringToArray(assetModel.label[i]));
    }
  }

  try {
    asset.addSync(attr);
    Logger.debug(`Asset added successfully, alias is ${assetModel.alias}`);
  } catch (error) {
    let err = error as BusinessError;
    Logger.error(`Failed to add asset, code is ${err.code}, message is ${err.message}`);
  }
}

/**
 * 查询关键资产
 * @param alias 关键资产别名
 * @returns 关键资产模型
 */
export async function queryAsset(alias: string): Promise<AssetModel> {
  let query: asset.AssetMap = new Map();
  let assetModel: AssetModel = {} as AssetModel;
  query.set(asset.Tag.ALIAS, stringToArray(alias));
  query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
  asset.query(query).then((res: Array<asset.AssetMap>) => {
    assetModel.alias = alias;
    assetModel.label = [];
    const secret: Uint8Array = res[0].get(asset.Tag.SECRET) as Uint8Array;
    assetModel.secret = arrayToString(secret);
    // 查询附属信息
    for (let i = 0; i < Object.keys(labelMap).length; i++) {
      let label: Uint8Array = res[0].get(labelMap[i]) as Uint8Array;
      if (label) {
        assetModel.label.push(arrayToString(label));
      }
    }
  }).catch((err: BusinessError) => {
    Logger.error(`Failed to query asset, code is ${err.code}, message is ${err.message}`);
    return Promise.reject(err);
  })
  return assetModel;
}

/**
 * 以同步方式查询关键资产（仅查询secret）
 * @param alias 关键资产别名
 * @returns 关键资产secret
 */
export function queryAssetSync(alias: string): string {
  try {
    let query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, stringToArray(alias));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    const result: Array<asset.AssetMap> = asset.querySync(query);
    const secret = result[0].get(asset.Tag.SECRET) as Uint8Array;
    if (secret) {
      return arrayToString(secret);
    }
  } catch (err) {
    Logger.error(`Failed to query asset, code is ${err.code}, message is ${err.message}`);
  }
  return '';
}

/**
 * 更新关键资产内容
 * @param alias 关键资产别名
 * @param tag 关键资产属性
 * @param value 关键资产内容
 */
export function updateAsset(alias: string, tag: asset.Tag, value: string) {
  let query: asset.AssetMap = new Map();
  query.set(asset.Tag.ALIAS, stringToArray(alias));
  let attrsToUpdate: asset.AssetMap = new Map();
  attrsToUpdate.set(tag, stringToArray(value));
  try {
    asset.updateSync(query, attrsToUpdate);
    Logger.debug(`Asset ${alias} updated successfully`);
  } catch (error) {
    let err = error as BusinessError;
    Logger.error(`Failed to update asset, code is ${err.code}, message is ${err.message}`);
  }
}

/**
 * 删除关键资产
 * @param alias 关键资产别名
 */
export function deleteAsset(alias: string) {
  let query: asset.AssetMap = new Map();
  query.set(asset.Tag.ALIAS, stringToArray(alias));
  try {
    asset.removeSync(query);
    Logger.debug(`Asset removed successfully`);
  } catch (error) {
    let err = error as BusinessError;
    Logger.error(`Failed to delete asset ${alias}, code is ${err.code}, message is ${err.message}`);
  }
}

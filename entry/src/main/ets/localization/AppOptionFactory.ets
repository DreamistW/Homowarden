import { AppDropdownOption } from '../model/AppUiModels';
import { CardBrandType, FilterType, IdentityTitleType } from '../utils/Constants';

export class AppOptionFactory {
  static identityTitles(): AppDropdownOption[] {
    const options: AppDropdownOption[] = [];
    options.push(AppDropdownOption.create($r('app.string.common_none'), IdentityTitleType.NONE));
    options.push(AppDropdownOption.create($r('app.string.identity_mr'), IdentityTitleType.MR));
    options.push(AppDropdownOption.create($r('app.string.identity_mrs'), IdentityTitleType.MRS));
    options.push(AppDropdownOption.create($r('app.string.identity_ms'), IdentityTitleType.MISS));
    options.push(AppDropdownOption.create($r('app.string.identity_mx'), IdentityTitleType.MX));
    options.push(AppDropdownOption.create($r('app.string.identity_dr'), IdentityTitleType.DR));
    return options;
  }

  static cardBrands(): AppDropdownOption[] {
    const options: AppDropdownOption[] = [];
    options.push(AppDropdownOption.create($r('app.string.common_none'), CardBrandType.NONE));
    options.push(AppDropdownOption.create($r('app.string.card_visa'), CardBrandType.VISA));
    options.push(AppDropdownOption.create($r('app.string.card_mastercard'), CardBrandType.MASTER));
    options.push(AppDropdownOption.create($r('app.string.card_amex'), CardBrandType.AME));
    options.push(AppDropdownOption.create($r('app.string.card_discover'), CardBrandType.DISCOVER));
    options.push(AppDropdownOption.create($r('app.string.card_diners'), CardBrandType.DINERS));
    options.push(AppDropdownOption.create($r('app.string.card_jcb'), CardBrandType.JCB));
    options.push(AppDropdownOption.create($r('app.string.card_maestro'), CardBrandType.MAESTRO));
    options.push(AppDropdownOption.create($r('app.string.card_unionpay'), CardBrandType.UNIONPAY));
    options.push(AppDropdownOption.create($r('app.string.card_rupay'), CardBrandType.RUPAY));
    options.push(AppDropdownOption.create($r('app.string.common_other'), CardBrandType.OTHER));
    return options;
  }

  static vaultFilters(total: number, login: number, note: number, card: number, identity: number,
    favorite: number, deleted: number): AppDropdownOption[] {
    const options: AppDropdownOption[] = [];
    options.push(AppDropdownOption.create($r('app.string.vault_filter_all', total), FilterType.ALL, total));
    options.push(AppDropdownOption.create($r('app.string.vault_filter_logins', login), FilterType.LOGINS, login));
    options.push(AppDropdownOption.create($r('app.string.vault_filter_notes', note), FilterType.NOTES, note));
    options.push(AppDropdownOption.create($r('app.string.vault_filter_cards', card), FilterType.CARDS, card));
    options.push(AppDropdownOption.create($r('app.string.vault_filter_identities', identity), FilterType.IDENTITIES,
      identity));
    options.push(AppDropdownOption.create($r('app.string.vault_filter_favorites', favorite), FilterType.FAVORITE,
      favorite));
    options.push(AppDropdownOption.create($r('app.string.vault_filter_trash', deleted), FilterType.DELETED, deleted));
    return options;
  }
}

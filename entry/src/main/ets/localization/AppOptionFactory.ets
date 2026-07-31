import { IBestDropdownMenuOption } from '@ibestservices/ibest-ui';
import { CardBrandType, FilterType, IdentityTitleType } from '../utils/Constants';

export class AppOptionFactory {
  static identityTitles(): IBestDropdownMenuOption[] {
    const options: IBestDropdownMenuOption[] = [];
    options.push({ text: $r('app.string.common_none'), value: IdentityTitleType.NONE });
    options.push({ text: $r('app.string.identity_mr'), value: IdentityTitleType.MR });
    options.push({ text: $r('app.string.identity_mrs'), value: IdentityTitleType.MRS });
    options.push({ text: $r('app.string.identity_ms'), value: IdentityTitleType.MISS });
    options.push({ text: $r('app.string.identity_mx'), value: IdentityTitleType.MX });
    options.push({ text: $r('app.string.identity_dr'), value: IdentityTitleType.DR });
    return options;
  }

  static cardBrands(): IBestDropdownMenuOption[] {
    const options: IBestDropdownMenuOption[] = [];
    options.push({ text: $r('app.string.common_none'), value: CardBrandType.NONE });
    options.push({ text: $r('app.string.card_visa'), value: CardBrandType.VISA });
    options.push({ text: $r('app.string.card_mastercard'), value: CardBrandType.MASTER });
    options.push({ text: $r('app.string.card_amex'), value: CardBrandType.AME });
    options.push({ text: $r('app.string.card_discover'), value: CardBrandType.DISCOVER });
    options.push({ text: $r('app.string.card_diners'), value: CardBrandType.DINERS });
    options.push({ text: $r('app.string.card_jcb'), value: CardBrandType.JCB });
    options.push({ text: $r('app.string.card_maestro'), value: CardBrandType.MAESTRO });
    options.push({ text: $r('app.string.card_unionpay'), value: CardBrandType.UNIONPAY });
    options.push({ text: $r('app.string.card_rupay'), value: CardBrandType.RUPAY });
    options.push({ text: $r('app.string.common_other'), value: CardBrandType.OTHER });
    return options;
  }

  static vaultFilters(total: number, login: number, note: number, card: number, identity: number,
    favorite: number, deleted: number): IBestDropdownMenuOption[] {
    const options: IBestDropdownMenuOption[] = [];
    options.push({ text: $r('app.string.vault_filter_all', total), value: FilterType.ALL });
    options.push({ text: $r('app.string.vault_filter_logins', login), value: FilterType.LOGINS });
    options.push({ text: $r('app.string.vault_filter_notes', note), value: FilterType.NOTES });
    options.push({ text: $r('app.string.vault_filter_cards', card), value: FilterType.CARDS });
    options.push({ text: $r('app.string.vault_filter_identities', identity), value: FilterType.IDENTITIES });
    options.push({ text: $r('app.string.vault_filter_favorites', favorite), value: FilterType.FAVORITE });
    options.push({ text: $r('app.string.vault_filter_trash', deleted), value: FilterType.DELETED });
    return options;
  }
}

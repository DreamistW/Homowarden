import { IBestIcon } from "@ibestservices/ibest-ui";

@Component
export struct SearchBar {
  placeholder: string = '';
  onSearch?: (text: string) => void;
  onClear?: () => void;

  @State searchText: string = '';

  build() {
    Row() {
      IBestIcon({
        name: 'search',
        iconSize: 16
      })
      
      TextInput({ 
        placeholder: this.placeholder,
        text: this.searchText 
      })
        .layoutWeight(1)
        .onChange((value: string) => {
          this.searchText = value;
          this.onSearch?.(value);
        })
      
      if (this.searchText.length > 0) {
        IBestIcon({
          name: 'cross',
          iconSize: 16,
          onIconClick: ()=>{
            this.searchText = '';
            this.onClear?.();
          }
        })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(8)
  }
} 
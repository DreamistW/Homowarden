import { getARouter,routerInitConfig } from '@abner/router';
import { AbilityStage } from '@kit.AbilityKit';
import { EntryRouterConfig } from '../../../EntryRouterConfig';

export class App extends AbilityStage {
  onCreate(): void {
    routerInitConfig([
      new EntryRouterConfig()
    ])
  }
}
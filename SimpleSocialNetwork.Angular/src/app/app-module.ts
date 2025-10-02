import { NgModule, provideBrowserGlobalErrorListeners, APP_INITIALIZER } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';

import { AppRoutingModule } from './app-routing-module';
import { App } from './app';
import { LoginComponent } from './login/login';
import { AppConfigService } from './app-config.service';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { apiBaseInterceptor } from './api-base.interceptor';

export function initConfig(cfg: AppConfigService) {
  return () => cfg.load();  // APP_INITIALIZER ждёт Promise из cfg.load()
}

@NgModule({
  declarations: [
    App,
    LoginComponent
  ],
  imports: [
    BrowserModule,
    AppRoutingModule
  ],
  providers: [
    provideHttpClient(withInterceptors([apiBaseInterceptor])),
    provideBrowserGlobalErrorListeners(),
    { provide: APP_INITIALIZER, useFactory: initConfig, deps: [AppConfigService], multi: true }
  ],
  bootstrap: [App]
})
export class AppModule { }

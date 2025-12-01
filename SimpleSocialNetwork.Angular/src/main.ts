import { bootstrapApplication } from '@angular/platform-browser';
import { materialDialogProvider } from './app/material-dialog.provider';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { AppComponent } from './app/app.component';
import { provideRouter } from '@angular/router';
import { LoginComponent } from './app/login/login.component';
import { RegisterComponent } from './app/register/register';
import { FeedComponent } from './app/feed/feed';
import { AdminComponent } from './app/admin/admin.component';
import { AccountSettingsComponent } from './app/account-settings/account-settings.component';
import { MessageComponent } from './app/message/message.component';
import { authGuard } from './app/guards/auth.guard';
import { authInterceptor } from './app/interceptors/auth.interceptor';
import { APP_INITIALIZER } from '@angular/core';
import { SettingsService } from './app/services/settings.service';

export function initializeApp(settingsService: SettingsService) {
  return () => settingsService.initialize();
}

bootstrapApplication(AppComponent, {
  providers: [
    provideHttpClient(withInterceptors([authInterceptor])),
    provideRouter([
      { path: '', redirectTo: 'login', pathMatch: 'full' },  // redirect root → /login
      { path: 'login', component: LoginComponent },           // /login route
      { path: 'register', component: RegisterComponent },     // /register route
      { path: 'message', component: MessageComponent },       // /message route - public
      { path: 'feed', component: FeedComponent, canActivate: [authGuard] },  // /feed route - protected
      { path: 'admin', component: AdminComponent, canActivate: [authGuard] },  // /admin route - protected
      { path: 'account-settings', component: AccountSettingsComponent, canActivate: [authGuard] },  // /account-settings route - protected
    ]),
    materialDialogProvider,
    {
      provide: APP_INITIALIZER,
      useFactory: initializeApp,
      deps: [SettingsService],
      multi: true
    }
  ]
}).catch(err => console.error(err));

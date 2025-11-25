import { bootstrapApplication } from '@angular/platform-browser';
import { AppComponent } from './app/app.component';
import { provideRouter } from '@angular/router';
import { LoginComponent } from './app/login/login.component';
import { RegisterComponent } from './app/register/register';

bootstrapApplication(AppComponent, {
  providers: [
    provideRouter([
      { path: '', redirectTo: 'login', pathMatch: 'full' },  // redirect root → /login
      { path: 'login', component: LoginComponent },           // /login route
      { path: 'register', component: RegisterComponent },     // /register route
    ])
  ]
}).catch(err => console.error(err));

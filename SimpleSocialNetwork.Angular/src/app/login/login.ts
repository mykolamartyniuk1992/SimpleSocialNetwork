import { Component } from '@angular/core';
import { LoginFormComponent } from '../login/login-form'; // standalone
import { LoginHeaderComponent } from '../login/login-header';

@Component({
  selector: 'app-login-page',
  standalone: true,
  imports: [LoginHeaderComponent, LoginFormComponent],
  templateUrl: './login-page.html',
  styleUrls: ['./login-page.css']
})
export class LoginComponent { }

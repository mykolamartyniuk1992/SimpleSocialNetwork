import { Component } from '@angular/core';
import { Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { AuthService } from '../services/auth.service';
import { SettingsService } from '../services/settings.service';
import { environment } from '../../environments/environment';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [
    MatCardModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatIconModule,
    ReactiveFormsModule
  ],
  templateUrl: './login.component.html',
  styleUrl: './login.component.css'
})
export class LoginComponent {
  loginForm: FormGroup;
  errorMessage: string = '';
  hidePassword: boolean = true;
  isDevelopment: boolean = !environment.production;

  constructor(
    private router: Router,
    private http: HttpClient,
    private fb: FormBuilder,
    private authService: AuthService,
    public settingsService: SettingsService
  ) {
    this.loginForm = this.fb.group({
      email: ['', [Validators.required, Validators.email]],
      password: ['', [Validators.required]]
    });

    // Watch email field and clear password when email is empty
    this.loginForm.get('email')?.valueChanges.subscribe(emailValue => {
      if (!emailValue || emailValue.trim() === '') {
        this.loginForm.get('password')?.setValue('', { emitEvent: false });
      }
    });
  }

  // Development-only methods
  // These methods will be tree-shaken in production build
  loginAsAdmin?: () => void;
  loginAsTestUser?: () => void;

  ngOnInit() {
    if (this.isDevelopment) {
      this.loginAsAdmin = () => {
        this.http.get<{ email: string; password: string }>(`${this.settingsService.apiUrl}/login/getadmincredentials`)
          .subscribe({
            next: (credentials) => {
              this.loginForm.patchValue({
                email: credentials.email,
                password: credentials.password
              });
              this.onSubmit();
            },
            error: (error) => {
              console.error('Failed to get admin credentials', error);
            }
          });
      };
      this.loginAsTestUser = () => {
        this.loginForm.patchValue({
          email: 'testuser@simplesocialnetwork.local',
          password: 'Test123!'
        });
        this.onSubmit();
      };
    }
  }

  onSubmit() {
    if (this.loginForm.valid) {
      const { email, password } = this.loginForm.value;
      
      this.http.post<{ id: number; token: string; isAdmin: boolean; name: string; photoUrl: string; verified: boolean; messagesLeft: number | null }>(`${this.settingsService.apiUrl}/login/login`, { email, password })
        .subscribe({
          next: (response) => {
            console.log('Login response:', response);
            console.log('User name from response:', response.name);
            console.log('Photo URL from response:', response.photoUrl);
            this.authService.setAuthData(response.id, response.token, response.isAdmin, response.name, response.photoUrl, response.verified, response.messagesLeft);
            
            // Always redirect to feed
            this.router.navigate(['/feed']);
          },
          error: (error) => {
            this.errorMessage = 'Invalid email or password';
            console.error('Login error:', error);
          }
        });
    }
  }

  navigateToRegister() {
    this.router.navigate(['/register']);
  }

  clearFields() {
    this.loginForm.patchValue({
      email: '',
      password: ''
    });
  }
}

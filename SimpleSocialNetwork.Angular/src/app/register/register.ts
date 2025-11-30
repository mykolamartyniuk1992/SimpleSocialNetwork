import { Component } from '@angular/core';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule, AbstractControl, ValidationErrors } from '@angular/forms';
import { Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { AuthService } from '../services/auth.service';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { CommonModule } from '@angular/common';
import { PhotoCropDialog } from '../photo-crop-dialog/photo-crop-dialog';
import { SettingsService } from '../services/settings.service';

@Component({
  selector: 'app-register',
  imports: [
    CommonModule,
    ReactiveFormsModule,
    MatCardModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatIconModule,
    MatDialogModule
  ],
  templateUrl: './register.html',
  styleUrl: './register.css',
})
export class RegisterComponent {
  registerForm: FormGroup;
  selectedFileName: string | null = null;
  croppedPhotoData: string | null = null;
  hidePassword: boolean = true;
  hideConfirmPassword: boolean = true;

  constructor(
    private fb: FormBuilder, 
    private router: Router, 
    private dialog: MatDialog,
    private http: HttpClient,
    private authService: AuthService,
    private settingsService: SettingsService
  ) {
    this.registerForm = this.fb.group({
      email: ['', [Validators.required, Validators.email]],
      username: ['', [Validators.required]],
      password: ['', [
        Validators.required,
        Validators.minLength(8),
        Validators.pattern(/^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]+$/)
      ]],
      confirmPassword: ['']
    }, { validators: this.passwordMatchValidator });
    
    // Trigger validation when either password field changes
    this.registerForm.get('password')?.valueChanges.subscribe(() => {
      const confirmPassword = this.registerForm.get('confirmPassword');
      if (confirmPassword?.value && confirmPassword?.touched) {
        confirmPassword.updateValueAndValidity({ onlySelf: false });
      }
    });
  }

  passwordMatchValidator(control: AbstractControl): ValidationErrors | null {
    const password = control.get('password');
    const confirmPassword = control.get('confirmPassword');
    
    if (!password || !confirmPassword) {
      return null;
    }
    
    // Don't validate if confirmPassword is empty
    if (!confirmPassword.value) {
      return null;
    }
    
    const passwordsMatch = password.value === confirmPassword.value;
    
    // Set error on confirmPassword field itself for better UX
    if (!passwordsMatch) {
      confirmPassword.setErrors({ passwordMismatch: true });
    } else if (confirmPassword.hasError('passwordMismatch')) {
      confirmPassword.setErrors(null);
    }
    
    return passwordsMatch ? null : { passwordMismatch: true };
  }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      this.selectedFileName = input.files[0].name;
      
      // Open crop dialog
      const dialogRef = this.dialog.open(PhotoCropDialog, {
        width: '600px',
        data: { event: event }
      });

      dialogRef.afterClosed().subscribe((result: string) => {
        if (result) {
          this.croppedPhotoData = result;
        } else {
          // User cancelled, reset file input
          this.selectedFileName = null;
          input.value = '';
        }
      });
    }
  }

  onSubmit(): void {
    if (this.registerForm.valid) {
      const registerData = {
        email: this.registerForm.value.email,
        name: this.registerForm.value.username,
        password: this.registerForm.value.password
      };

      this.http.post<{ id: number; token: string; isAdmin: boolean; name: string; photoUrl: string; verified: boolean; messagesLeft: number | null }>(`${this.settingsService.apiUrl}/Register/Register`, registerData)
        .subscribe({
          next: async (response) => {
            console.log('Registration successful', response);
            
            // Save auth data
            this.authService.setAuthData(response.id, response.token, response.isAdmin, response.name, response.photoUrl, response.verified, response.messagesLeft);
            
            // Upload photo if available, wait for it to complete before redirecting
            if (this.croppedPhotoData && response.id) {
              await this.uploadPhoto(response.id);
            }
            
            // Navigate to feed after photo upload (or immediately if no photo)
            this.router.navigate(['/feed']);
          },
          error: (error) => {
            console.error('Registration failed', error);
            // TODO: Show error message to user
          }
        });
    }
  }

  private async uploadPhoto(profileId: number): Promise<void> {
    // Convert base64 to blob
    const base64Data = this.croppedPhotoData!.split(',')[1];
    const byteCharacters = atob(base64Data);
    const byteNumbers = new Array(byteCharacters.length);
    for (let i = 0; i < byteCharacters.length; i++) {
      byteNumbers[i] = byteCharacters.charCodeAt(i);
    }
    const byteArray = new Uint8Array(byteNumbers);
    const blob = new Blob([byteArray], { type: 'image/png' });

    // Create FormData and upload
    const formData = new FormData();
    formData.append('photo', blob, `${profileId}.png`);
    formData.append('profileId', profileId.toString());

    return new Promise<void>((resolve, reject) => {
      this.http.post(`${this.settingsService.apiUrl}/Profile/UploadPhoto`, formData)
        .subscribe({
          next: () => {
            console.log('Photo uploaded successfully');
            
            // Update photo URL in auth service after successful upload
            const photoUrl = `/api/profile/getphoto?profileId=${profileId}`;
            this.authService.updatePhotoUrl(photoUrl);
            
            resolve();
          },
          error: (error) => {
            console.error('Photo upload failed', error);
            // Resolve anyway so registration flow continues
            resolve();
          }
        });
    });
  }

  navigateToLogin(): void {
    this.router.navigate(['/login']);
  }
}

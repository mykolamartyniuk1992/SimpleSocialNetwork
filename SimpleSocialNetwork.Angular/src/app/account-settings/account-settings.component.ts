import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule, AbstractControl, ValidationErrors } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatDialogModule, MatDialog } from '@angular/material/dialog';
import { ImageCropperComponent, ImageCroppedEvent, LoadedImage } from 'ngx-image-cropper';
import { AuthService } from '../services/auth.service';
import { environment } from '../../environments/environment';
import { Router } from '@angular/router';

@Component({
  selector: 'app-image-crop-dialog',
  standalone: true,
  imports: [CommonModule, MatDialogModule, MatButtonModule, ImageCropperComponent],
  template: `
    <h2 mat-dialog-title>Crop Photo</h2>
    <mat-dialog-content>
      <image-cropper
        [imageChangedEvent]="imageChangedEvent"
        [maintainAspectRatio]="true"
        [aspectRatio]="1"
        [resizeToWidth]="300"
        format="png"
        (imageCropped)="imageCropped($event)"
        (imageLoaded)="imageLoaded($event)"
        (cropperReady)="cropperReady()"
        (loadImageFailed)="loadImageFailed()">
      </image-cropper>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>Cancel</button>
      <button mat-raised-button color="primary" [mat-dialog-close]="croppedImage">Crop & Save</button>
    </mat-dialog-actions>
  `,
  styles: [`
    mat-dialog-content {
      min-width: 400px;
      min-height: 400px;
      display: flex;
      justify-content: center;
      align-items: center;
    }
  `]
})
export class ImageCropDialogComponent {
  imageChangedEvent: any = '';
  croppedImage: any = '';

  imageCropped(event: ImageCroppedEvent) {
    this.croppedImage = event.blob;
  }

  imageLoaded(image: LoadedImage) {
    console.log('Image loaded');
  }

  cropperReady() {
    console.log('Cropper ready');
  }

  loadImageFailed() {
    console.log('Load failed');
  }
}

@Component({
  selector: 'app-account-settings',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    MatCardModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatDialogModule
  ],
  templateUrl: './account-settings.component.html',
  styleUrls: ['./account-settings.component.css']
})
export class AccountSettingsComponent implements OnInit {
  profileForm: FormGroup;
  passwordForm: FormGroup;
  selectedFile: File | null = null;
  photoPreview: string | null = null;
  saving = false;
  changingPassword = false;
  deleting = false;
  hideOldPassword = true;
  hideNewPassword = true;
  hideConfirmPassword = true;

  get isVerified(): boolean {
    return this.authService.isVerified();
  }

  get messagesLeft(): number | null {
    return this.authService.getMessagesLeft();
  }

  constructor(
    private fb: FormBuilder,
    private http: HttpClient,
    private authService: AuthService,
    private dialog: MatDialog,
    private router: Router
  ) {
    this.profileForm = this.fb.group({
      name: ['', [Validators.required, Validators.minLength(2)]]
    });

    this.passwordForm = this.fb.group({
      oldPassword: ['', [
        Validators.required,
        Validators.minLength(8),
        Validators.pattern(/^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]+$/)
      ]],
      newPassword: ['', [
        Validators.required,
        Validators.minLength(8),
        Validators.pattern(/^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]+$/)
      ]],
      confirmPassword: ['']
    }, { validators: this.passwordMatchValidator });

    // Trigger validation when newPassword field changes
    this.passwordForm.get('newPassword')?.valueChanges.subscribe(() => {
      const confirmPassword = this.passwordForm.get('confirmPassword');
      if (confirmPassword?.value && confirmPassword?.touched) {
        confirmPassword.updateValueAndValidity({ onlySelf: false });
      }
    });
  }

  ngOnInit(): void {
    this.loadProfile();
  }

  passwordMatchValidator(control: AbstractControl): ValidationErrors | null {
    const newPassword = control.get('newPassword');
    const confirmPassword = control.get('confirmPassword');
    
    if (!newPassword || !confirmPassword) {
      return null;
    }
    
    // Don't validate if confirmPassword is empty
    if (!confirmPassword.value) {
      return null;
    }
    
    const passwordsMatch = newPassword.value === confirmPassword.value;
    
    // Set error on confirmPassword field itself for better UX
    if (!passwordsMatch) {
      confirmPassword.setErrors({ passwordMismatch: true });
    } else if (confirmPassword.hasError('passwordMismatch')) {
      confirmPassword.setErrors(null);
    }
    
    return passwordsMatch ? null : { passwordMismatch: true };
  }

  loadProfile(): void {
    const userName = this.authService.getUserName();
    const photoUrl = this.authService.getPhotoUrl();
    
    if (userName) {
      this.profileForm.patchValue({ name: userName });
    }
    
    if (photoUrl) {
      this.photoPreview = this.getFullPhotoUrl(photoUrl);
    }
  }

  getFullPhotoUrl(photoPath: string): string {
    if (photoPath.startsWith('http')) return photoPath;
    const baseUrl = environment.apiUrl.replace('/api', '');
    // Add timestamp to bypass browser cache
    const separator = photoPath.includes('?') ? '&' : '?';
    return `${baseUrl}${photoPath}${separator}t=${Date.now()}`;
  }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files[0]) {
      const dialogRef = this.dialog.open(ImageCropDialogComponent, {
        width: '500px',
        disableClose: true
      });
      
      dialogRef.componentInstance.imageChangedEvent = event;
      
      dialogRef.afterClosed().subscribe((croppedBlob: Blob | null) => {
        if (croppedBlob) {
          // Convert blob to file
          this.selectedFile = new File([croppedBlob], input.files![0].name, { type: 'image/png' });
          
          // Preview the cropped image
          const reader = new FileReader();
          reader.onload = (e: ProgressEvent<FileReader>) => {
            this.photoPreview = e.target?.result as string;
          };
          reader.readAsDataURL(this.selectedFile);
        }
        // Reset input
        input.value = '';
      });
    }
  }

  saveProfile(): void {
    if (this.profileForm.invalid) {
      return;
    }

    this.saving = true;
    const formData = new FormData();
    formData.append('name', this.profileForm.get('name')?.value);
    
    if (this.selectedFile) {
      formData.append('photo', this.selectedFile);
    }

    this.http.post(`${environment.apiUrl}/profile/updateprofile`, formData)
      .subscribe({
        next: (response: any) => {
          // Defer profile updates to avoid change detection errors
          setTimeout(() => {
            this.authService.updateUserName(this.profileForm.get('name')?.value);
            if (response.photoPath) {
              this.authService.updatePhotoUrl(response.photoPath);
            }
          }, 0);
          alert('Profile updated successfully!');
          this.saving = false;
          this.selectedFile = null;
        },
        error: (error) => {
          console.error('Failed to update profile', error);
          alert('Failed to update profile');
          this.saving = false;
        }
      });
  }

  changePassword(): void {
    if (this.passwordForm.invalid) {
      return;
    }

    this.changingPassword = true;
    const data = {
      oldPassword: this.passwordForm.get('oldPassword')?.value,
      newPassword: this.passwordForm.get('newPassword')?.value
    };

    this.http.post(`${environment.apiUrl}/profile/changepassword`, data)
      .subscribe({
        next: () => {
          alert('Password changed successfully!');
          this.passwordForm.reset();
          this.changingPassword = false;
        },
        error: (error) => {
          console.error('Failed to change password', error);
          alert('Failed to change password. Please check your old password.');
          this.changingPassword = false;
        }
      });
  }

  deleteAccount(): void {
    const confirmation = confirm(
      'Are you sure you want to delete your account? This action cannot be undone. All your posts, comments, and likes will be permanently deleted.'
    );

    if (!confirmation) {
      return;
    }

    this.deleting = true;

    this.http.delete(`${environment.apiUrl}/profile/deleteownaccount`)
      .subscribe({
        next: () => {
          this.authService.logout();
          this.router.navigate(['/message'], {
            state: {
              message: 'Your account has been successfully deleted.',
              icon: 'delete_forever'
            }
          });
        },
        error: (error) => {
          console.error('Failed to delete account', error);
          alert('Failed to delete account. Please try again.');
          this.deleting = false;
        }
      });
  }
}

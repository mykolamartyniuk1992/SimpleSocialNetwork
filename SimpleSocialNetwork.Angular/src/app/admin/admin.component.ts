import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule, FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { MatTableModule } from '@angular/material/table';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatTooltipModule } from '@angular/material/tooltip';
import { environment } from '../../environments/environment';

interface User {
  id: number;
  email: string;
  name: string;
  photoPath?: string;
  isSystemUser: boolean;
  isAdmin: boolean;
  verified: boolean;
  messagesLeft?: number | null;
}

@Component({
  selector: 'app-admin',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    FormsModule,
    MatCardModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatIconModule,
    MatSnackBarModule,
    MatTableModule,
    MatProgressSpinnerModule,
    MatTooltipModule
  ],
  templateUrl: './admin.component.html',
  styleUrl: './admin.component.css'
})
export class AdminComponent implements OnInit {
  apiConfigForm: FormGroup;
  messageLimitForm: FormGroup;
  currentApiUrl: string = environment.apiUrl;
  defaultMessageLimit: number = 100;
  saving: boolean = false;
  
  users: User[] = [];
  loadingUsers: boolean = false;
  verifyingUsers: { [key: number]: boolean } = {};
  deletingUsers: { [key: number]: boolean } = {};
  editingMessageLimit: { [key: number]: boolean } = {};
  displayedColumns: string[] = ['photo', 'email', 'name', 'isSystemUser', 'isAdmin', 'verified', 'messagesLeft', 'actions'];

  constructor(
    private fb: FormBuilder,
    private snackBar: MatSnackBar,
    private http: HttpClient
  ) {
    // Load saved API URL from localStorage if exists
    const savedApiUrl = localStorage.getItem('apiUrl');
    if (savedApiUrl) {
      this.currentApiUrl = savedApiUrl;
    }

    this.apiConfigForm = this.fb.group({
      apiUrl: [this.currentApiUrl, [Validators.required, Validators.pattern(/^https?:\/\/.+/)]]
    });

    this.messageLimitForm = this.fb.group({
      messageLimit: [this.defaultMessageLimit, [Validators.required, Validators.min(1), Validators.max(10000)]]
    });
  }

  ngOnInit(): void {
    this.loadDefaultMessageLimit();
    this.loadUsers();
  }

  loadDefaultMessageLimit(): void {
    // Load from backend config first, fallback to environment config
    this.http.get<{ defaultMessageLimit: number }>(`${environment.apiUrl}/config/getdefaultmessagelimit`)
      .subscribe({
        next: (response) => {
          this.defaultMessageLimit = response.defaultMessageLimit;
          this.messageLimitForm.patchValue({ messageLimit: this.defaultMessageLimit });
        },
        error: () => {
          // Fallback to environment config
          this.defaultMessageLimit = environment.defaultMessageLimit;
          this.messageLimitForm.patchValue({ messageLimit: this.defaultMessageLimit });
        }
      });
  }

  onSaveApiUrl(): void {
    if (this.apiConfigForm.valid) {
      const newApiUrl = this.apiConfigForm.value.apiUrl;
      localStorage.setItem('apiUrl', newApiUrl);
      this.currentApiUrl = newApiUrl;
      
      this.snackBar.open('API URL saved successfully! Please refresh the page for changes to take effect.', 'Close', {
        duration: 5000,
        horizontalPosition: 'center',
        verticalPosition: 'top'
      });
    }
  }

  onResetToDefault(): void {
    const defaultUrl = environment.apiUrl;
    this.apiConfigForm.patchValue({ apiUrl: defaultUrl });
    localStorage.removeItem('apiUrl');
    this.currentApiUrl = defaultUrl;
    
    this.snackBar.open('API URL reset to default. Please refresh the page.', 'Close', {
      duration: 3000,
      horizontalPosition: 'center',
      verticalPosition: 'top'
    });
  }

  onSaveMessageLimit(): void {
    if (this.messageLimitForm.valid && !this.saving) {
      this.saving = true;
      const newLimit = this.messageLimitForm.value.messageLimit;
      
      // Call API to update all existing unverified users and save to config
      this.http.post(`${environment.apiUrl}/profile/updatemessagelimits`, { messageLimit: newLimit })
        .subscribe({
          next: () => {
            this.defaultMessageLimit = newLimit;
            
            this.saving = false;
            this.snackBar.open(`Message limit set to ${newLimit} for all unverified users`, 'Close', {
              duration: 4000,
              horizontalPosition: 'center',
              verticalPosition: 'top'
            });
          },
          error: (error) => {
            console.error('Failed to update message limits', error);
            this.saving = false;
            
            // Extract error message and stack trace from response
            const errorMessage = error.error?.message || error.message || 'Failed to update message limits';
            const stackTrace = error.error?.stackTrace || '';
            
            // Display error with stack trace
            const fullErrorMessage = stackTrace 
              ? `${errorMessage}\n\nStack Trace:\n${stackTrace}`
              : errorMessage;
            
            this.snackBar.open(fullErrorMessage, 'Close', {
              horizontalPosition: 'center',
              verticalPosition: 'top',
              panelClass: ['error-snackbar']
            });
          }
        });
    }
  }

  loadUsers(): void {
    this.loadingUsers = true;
    this.http.get<User[]>(`${environment.apiUrl}/profile/getallusers`)
      .subscribe({
        next: (users) => {
          this.users = users;
          this.loadingUsers = false;
        },
        error: (error) => {
          console.error('Failed to load users', error);
          this.loadingUsers = false;
          
          // Extract error message and stack trace from response
          const errorMessage = error.error?.message || error.message || 'Failed to load users';
          const stackTrace = error.error?.stackTrace || '';
          
          // Display error with stack trace
          const fullErrorMessage = stackTrace 
            ? `${errorMessage}\n\nStack Trace:\n${stackTrace}`
            : errorMessage;
          
          this.snackBar.open(fullErrorMessage, 'Close', {
            panelClass: ['error-snackbar']
          });
        }
      });
  }

  verifyUser(user: User): void {
    this.verifyingUsers[user.id] = true;
    this.http.post(`${environment.apiUrl}/profile/setverified`, { profileId: user.id, verified: true })
      .subscribe({
        next: () => {
          user.verified = true;
          this.verifyingUsers[user.id] = false;
          this.snackBar.open(`${user.name} has been verified`, 'Close', {
            duration: 3000
          });
        },
        error: (error) => {
          console.error('Failed to verify user', error);
          this.verifyingUsers[user.id] = false;
          
          const errorMessage = error.error?.message || 'Failed to verify user';
          const stackTrace = error.error?.stackTrace || '';
          const fullErrorMessage = stackTrace 
            ? `${errorMessage}\n\nStack Trace:\n${stackTrace}`
            : errorMessage;
          
          this.snackBar.open(fullErrorMessage, 'Close', {
            panelClass: ['error-snackbar']
          });
        }
      });
  }

  unverifyUser(user: User): void {
    this.verifyingUsers[user.id] = true;
    this.http.post(`${environment.apiUrl}/profile/setverified`, { profileId: user.id, verified: false })
      .subscribe({
        next: () => {
          user.verified = false;
          this.verifyingUsers[user.id] = false;
          this.snackBar.open(`${user.name} has been unverified`, 'Close', {
            duration: 3000
          });
        },
        error: (error) => {
          console.error('Failed to unverify user', error);
          this.verifyingUsers[user.id] = false;
          
          const errorMessage = error.error?.message || 'Failed to unverify user';
          const stackTrace = error.error?.stackTrace || '';
          const fullErrorMessage = stackTrace 
            ? `${errorMessage}\n\nStack Trace:\n${stackTrace}`
            : errorMessage;
          
          this.snackBar.open(fullErrorMessage, 'Close', {
            panelClass: ['error-snackbar']
          });
        }
      });
  }

  deleteUser(user: User): void {
    const confirmation = confirm(`Are you sure you want to delete ${user.name}? This will permanently delete the user and all their posts, comments, and likes. This action cannot be undone.`);
    if (!confirmation) {
      return;
    }

    this.deletingUsers[user.id] = true;
    this.http.delete(`${environment.apiUrl}/profile/deleteuser?profileId=${user.id}`)
      .subscribe({
        next: () => {
          // Remove user from the list
          this.users = this.users.filter(u => u.id !== user.id);
          this.deletingUsers[user.id] = false;
          this.snackBar.open(`${user.name} has been deleted`, 'Close', {
            duration: 3000
          });
        },
        error: (error) => {
          console.error('Failed to delete user', error);
          this.deletingUsers[user.id] = false;
          
          const errorMessage = error.error?.message || 'Failed to delete user';
          const stackTrace = error.error?.stackTrace || '';
          const fullErrorMessage = stackTrace 
            ? `${errorMessage}\n\nStack Trace:\n${stackTrace}`
            : errorMessage;
          
          this.snackBar.open(fullErrorMessage, 'Close', {
            panelClass: ['error-snackbar']
          });
        }
      });
  }

  updateUserMessageLimit(user: User, newLimit: number): void {
    if (newLimit < 0) {
      this.snackBar.open('Message limit cannot be negative', 'Close', {
        duration: 3000
      });
      return;
    }

    this.editingMessageLimit[user.id] = true;
    this.http.post(`${environment.apiUrl}/profile/updateusermessagelimit`, { profileId: user.id, messageLimit: newLimit })
      .subscribe({
        next: () => {
          user.messagesLeft = newLimit;
          this.editingMessageLimit[user.id] = false;
          this.snackBar.open(`Message limit for ${user.name} updated to ${newLimit}`, 'Close', {
            duration: 3000
          });
        },
        error: (error) => {
          console.error('Failed to update message limit', error);
          this.editingMessageLimit[user.id] = false;
          
          const errorMessage = error.error?.message || 'Failed to update message limit';
          const stackTrace = error.error?.stackTrace || '';
          const fullErrorMessage = stackTrace 
            ? `${errorMessage}\n\nStack Trace:\n${stackTrace}`
            : errorMessage;
          
          this.snackBar.open(fullErrorMessage, 'Close', {
            panelClass: ['error-snackbar']
          });
        }
      });
  }

  preventNegative(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.value && parseInt(input.value) < 0) {
      input.value = '0';
    }
  }

  getFullPhotoUrl(photoPath?: string): string {
    if (!photoPath) return '';
    if (photoPath.startsWith('http')) return photoPath;
    const baseUrl = environment.apiUrl.replace('/api', '');
    return `${baseUrl}${photoPath}`;
  }
}

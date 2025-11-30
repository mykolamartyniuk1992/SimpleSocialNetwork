import { Component, NgZone, OnDestroy, OnInit } from "@angular/core";
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatMenuModule } from '@angular/material/menu';
import { MatDividerModule } from '@angular/material/divider';
import { MatTooltipModule } from '@angular/material/tooltip';
import { AuthService } from '../services/auth.service';
import { SettingsService } from '../services/settings.service';
import { Subscription } from 'rxjs';

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [
    CommonModule,
    MatToolbarModule,
    MatIconModule,
    MatButtonModule,
    MatMenuModule,
    MatDividerModule,
    MatTooltipModule
  ],
  templateUrl: './header.component.html',
  styleUrls: ['./header.component.css']
})
export class HeaderComponent implements OnInit, OnDestroy {
  connectionError = false;
  private connectionErrorSub?: Subscription;
  userName: string = '';
  photoUrl: string | null = null;
  fullPhotoUrl: string = '';
  private subscription: Subscription;

  constructor(
    private authService: AuthService,
    private router: Router,
    private ngZone: NgZone,
    private http: HttpClient,
    public settingsService: SettingsService
  ) {
    // Subscribe to profile updates
    this.subscription = this.authService.profileUpdated$.subscribe(() => {
      this.loadUserProfile();
    });
    this.loadUserProfile();
    this.connectionErrorSub = this.settingsService.connectionError$.subscribe(err => {
      this.connectionError = err;
    });
  }

  ngOnInit(): void {
    // Fetch messagesLeft from backend on initialization
    if (this.authService.isAuthenticated() && !this.authService.isVerified()) {
      this.http.get<{ messagesLeft: number | null }>(`${this.settingsService.apiUrl}/profile/GetCurrentUserMessagesLeft`)
        .subscribe({
          next: (response) => {
            this.authService.updateMessagesLeft(response.messagesLeft);
          },
          error: (error) => {
            console.error('Failed to fetch messagesLeft on init', error);
          }
        });
    }
  }

  ngOnDestroy(): void {
    this.subscription.unsubscribe();
    this.connectionErrorSub?.unsubscribe();
  }

  private loadUserProfile(): void {
    this.userName = this.authService.getUserName() || 'User';
    this.photoUrl = this.authService.getPhotoUrl();
    console.log('photoUrl loaded:', this.photoUrl);
    // Generate new timestamp each time profile is loaded to force cache refresh
    this.fullPhotoUrl = this.buildFullPhotoUrl();
    console.log('fullPhotoUrl generated:', this.fullPhotoUrl);
  }

  get isAuthenticated(): boolean {
    return this.authService.isAuthenticated();
  }

  get isAdmin(): boolean {
    return this.authService.isAdmin();
  }

  get isVerified(): boolean {
    return this.authService.isVerified();
  }

  get messagesLeft(): number | null {
    return this.authService.getMessagesLeft();
  }

  get showMessagesLeft(): boolean {
    return !this.isVerified && this.messagesLeft !== null;
  }

  private buildFullPhotoUrl(): string {
    const photoUrl = this.photoUrl;
    if (photoUrl && !photoUrl.startsWith('http')) {
      const apiBase = this.settingsService.apiUrl.replace('/api', '');
      const separator = photoUrl.includes('?') ? '&' : '?';
      return `${apiBase}${photoUrl}${separator}t=${Date.now()}`;
    }
    return photoUrl || '';
  }

  getFullPhotoUrl(): string {
    return this.fullPhotoUrl;
  }

  navigateToFeed(): void {
    this.router.navigate(['/feed']);
  }

  navigateToAdmin(): void {
    this.router.navigate(['/admin']);
  }

  navigateToSettings(): void {
    this.router.navigate(['/account-settings']);
  }

  logout(): void {
    this.authService.logout();
    this.router.navigate(['/login']);
  }
}
import { Injectable } from '@angular/core';
import { Subject } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private readonly TOKEN_KEY = 'auth_token';
  private readonly USER_ID_KEY = 'user_id';
  private readonly IS_ADMIN_KEY = 'is_admin';
  private readonly IS_VERIFIED_KEY = 'is_verified';
  private readonly MESSAGES_LEFT_KEY = 'messages_left';
  private readonly USER_NAME_KEY = 'user_name';
  private readonly PHOTO_URL_KEY = 'photo_url';

  private profileUpdated = new Subject<void>();
  profileUpdated$ = this.profileUpdated.asObservable();

  setAuthData(userId: number, token: string, isAdmin: boolean = false, userName?: string, photoUrl?: string, isVerified: boolean = false, messagesLeft?: number | null): void {
    localStorage.setItem(this.USER_ID_KEY, userId.toString());
    localStorage.setItem(this.TOKEN_KEY, token);
    localStorage.setItem(this.IS_ADMIN_KEY, isAdmin.toString());
    localStorage.setItem(this.IS_VERIFIED_KEY, isVerified.toString());
    if (messagesLeft !== undefined && messagesLeft !== null) {
      localStorage.setItem(this.MESSAGES_LEFT_KEY, messagesLeft.toString());
    } else {
      localStorage.removeItem(this.MESSAGES_LEFT_KEY);
    }
    if (userName) {
      localStorage.setItem(this.USER_NAME_KEY, userName);
    }
    if (photoUrl) {
      localStorage.setItem(this.PHOTO_URL_KEY, photoUrl);
    }
    // Notify subscribers that profile data has been updated
    this.profileUpdated.next();
  }

  getToken(): string | null {
    return localStorage.getItem(this.TOKEN_KEY);
  }

  getUserId(): number | null {
    const id = localStorage.getItem(this.USER_ID_KEY);
    return id ? parseInt(id, 10) : null;
  }

  getUserName(): string | null {
    return localStorage.getItem(this.USER_NAME_KEY);
  }

  getPhotoUrl(): string | null {
    return localStorage.getItem(this.PHOTO_URL_KEY);
  }

  isAdmin(): boolean {
    return localStorage.getItem(this.IS_ADMIN_KEY) === 'true';
  }

  isVerified(): boolean {
    return localStorage.getItem(this.IS_VERIFIED_KEY) === 'true';
  }

  getMessagesLeft(): number | null {
    const value = localStorage.getItem(this.MESSAGES_LEFT_KEY);
    return value ? parseInt(value, 10) : null;
  }

  updateMessagesLeft(messagesLeft: number | null): void {
    if (messagesLeft !== null) {
      localStorage.setItem(this.MESSAGES_LEFT_KEY, messagesLeft.toString());
    } else {
      localStorage.removeItem(this.MESSAGES_LEFT_KEY);
    }
    this.profileUpdated.next();
  }

  isAuthenticated(): boolean {
    return !!this.getToken();
  }

  updateUserName(userName: string): void {
    localStorage.setItem(this.USER_NAME_KEY, userName);
    this.profileUpdated.next();
  }

  updatePhotoUrl(photoUrl: string): void {
    localStorage.setItem(this.PHOTO_URL_KEY, photoUrl);
    this.profileUpdated.next();
  }

  updateVerified(verified: boolean): void {
    localStorage.setItem(this.IS_VERIFIED_KEY, verified.toString());
    this.profileUpdated.next();
  }

  logout(): void {
    localStorage.removeItem(this.TOKEN_KEY);
    localStorage.removeItem(this.USER_ID_KEY);
    localStorage.removeItem(this.IS_ADMIN_KEY);
    localStorage.removeItem(this.IS_VERIFIED_KEY);
    localStorage.removeItem(this.MESSAGES_LEFT_KEY);
    localStorage.removeItem(this.USER_NAME_KEY);
    localStorage.removeItem(this.PHOTO_URL_KEY);
  }
}

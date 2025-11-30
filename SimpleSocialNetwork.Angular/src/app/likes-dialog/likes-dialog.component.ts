import { Component, Inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MAT_DIALOG_DATA, MatDialogRef, MatDialogModule } from '@angular/material/dialog';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatListModule } from '@angular/material/list';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatDividerModule } from '@angular/material/divider';
import { HttpClient } from '@angular/common/http';
import { SettingsService } from '../services/settings.service';

interface LikeUser {
  profileName: string;
  photoPath?: string;
}

@Component({
  selector: 'app-likes-dialog',
  standalone: true,
  imports: [
    CommonModule,
    MatDialogModule,
    MatIconModule,
    MatButtonModule,
    MatListModule,
    MatProgressSpinnerModule,
    MatDividerModule,
  ],
  templateUrl: './likes-dialog.component.html',
  styleUrls: ['./likes-dialog.component.css'],
})
export class LikesDialogComponent {
  likes: LikeUser[] = [];
  loading = false;
  page = 1;
  pageSize = 5;
  totalCount = 0;
  totalPages = 0;

  constructor(
    public dialogRef: MatDialogRef<LikesDialogComponent>,
    @Inject(MAT_DIALOG_DATA) public data: { feedId: number },
    private http: HttpClient,
    private settingsService: SettingsService
  ) {
    this.loadLikes();
  }

  getFullPhotoUrl(photoPath?: string): string {
    if (!photoPath) return '';

    // если пришёл полный URL
    if (photoPath.startsWith('http')) return photoPath;

    // если API endpoint типа /api/profile/getphoto...
    if (photoPath.startsWith('/api')) {
      const base = this.settingsService.apiUrl.replace(/\/api\/?$/, '');
      return `${base}${photoPath}`;
    }

    const base = this.settingsService.apiUrl.replace(/\/api\/?$/, '');
    return `${base}${photoPath}`;
  }

  onImgError(event: Event): void {
    const img = event.target as HTMLImageElement;
    img.src = 'assets/default-avatar.png';
  }

  loadLikes(page: number = 1): void {
    this.loading = true;
    this.http
      .get<{ likes: LikeUser[]; totalCount: number }>(
        `${this.settingsService.apiUrl}/feed/getlikespaginated/${this.data.feedId}?page=${page}&pageSize=${this.pageSize}`
      )
      .subscribe({
        next: (res) => {
          this.likes = res.likes;
          this.totalCount = res.totalCount;
          this.page = page;
          this.totalPages = Math.max(1, Math.ceil(res.totalCount / this.pageSize));
          this.loading = false;
        },
        error: () => {
          this.likes = [];
          this.loading = false;
        },
      });
  }

  goToPage(page: number): void {
    if (page < 1 || page > this.totalPages) return;
    this.loadLikes(page);
  }

  close(): void {
    this.dialogRef.close();
  }
}

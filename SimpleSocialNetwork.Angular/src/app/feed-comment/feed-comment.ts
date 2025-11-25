import { Component, Input, OnInit, OnDestroy } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { environment } from '../../environments/environment';
import { AuthService } from '../services/auth.service';

interface Like {
  id: number;
  feedId: number;
  profileId: number;
  profileName?: string;
}

interface FeedItem {
  id: number;
  profileId: number;
  name: string;
  text: string;
  date: string;
  likes: Like[];
  isLiked?: boolean;
  profilePhotoPath?: string;
  parentId?: number;
  comments?: FeedItem[];
  showComments?: boolean;
  showCommentForm?: boolean;
  commentText?: string;
}

@Component({
  selector: 'app-feed-comment',
  imports: [
    CommonModule,
    FormsModule,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatFormFieldModule,
    MatInputModule
  ],
  templateUrl: './feed-comment.html',
  styleUrl: './feed-comment.css',
})
export class FeedCommentComponent implements OnInit, OnDestroy {
  get isPostingDisabled(): boolean {
    return !this.authService.isVerified() && this.messagesLeft !== null && this.messagesLeft <= 0;
  }
  @Input() comment!: FeedItem;
  liking: { [key: number]: boolean } = {};
  private profileUpdateSubscription?: any;
  messagesLeft: number | null = null;

  constructor(
    private http: HttpClient,
    private authService: AuthService
  ) {
    this.messagesLeft = this.authService.getMessagesLeft();
  }

  ngOnInit(): void {
    // Subscribe to profile updates to refresh messagesLeft
    this.profileUpdateSubscription = this.authService.profileUpdated$.subscribe(() => {
      this.messagesLeft = this.authService.getMessagesLeft();
    });
  }

  ngOnDestroy(): void {
    if (this.profileUpdateSubscription) {
      this.profileUpdateSubscription.unsubscribe();
    }
  }

  getLikesCount(feed: FeedItem): number {
    return feed.likes?.length || 0;
  }

  toggleLike(feed: FeedItem): void {
    if (this.liking[feed.id]) {
      return;
    }

    const currentUserId = this.authService.getUserId();
    if (!currentUserId) {
      return;
    }
    
    this.liking[feed.id] = true;
    
    if (feed.isLiked) {
      const userLike = feed.likes?.find(like => like.profileId === currentUserId);
      if (!userLike) {
        console.error('Cannot find like to remove');
        this.liking[feed.id] = false;
        return;
      }
      
      this.http.post(`${environment.apiUrl}/feed/dislike`, { id: userLike.id, feedId: feed.id })
        .subscribe({
          next: () => {
            // SignalR will update all clients
            this.liking[feed.id] = false;
          },
          error: (error) => {
            console.error('Failed to unlike post', error);
            this.liking[feed.id] = false;
          }
        });
    } else {
      this.http.post<{ id: number; feedId: number; profileId: number }>(`${environment.apiUrl}/feed/like`, { feedId: feed.id })
        .subscribe({
          next: () => {
            // SignalR will update all clients
            this.liking[feed.id] = false;
          },
          error: (error) => {
            console.error('Failed to like post', error);
            this.liking[feed.id] = false;
          }
        });
    }
  }

  toggleComments(feed: FeedItem): void {
    feed.showComments = !feed.showComments;
    if (feed.showComments && (!feed.comments || feed.comments.length === 0)) {
      this.loadComments(feed);
    }
  }

  loadComments(feed: FeedItem): void {
    this.http.get<FeedItem[]>(`${environment.apiUrl}/feed/getcomments/${feed.id}`)
      .subscribe({
        next: (comments) => {
          const currentUserId = this.authService.getUserId();
          feed.comments = comments.map(comment => this.processComment(comment, currentUserId));
        },
        error: (error) => {
          console.error('Failed to load comments', error);
        }
      });
  }

  private processComment(comment: FeedItem, currentUserId: number | null): FeedItem {
    comment.isLiked = comment.likes?.some(like => like.profileId === currentUserId) || false;
    if (comment.comments && comment.comments.length > 0) {
      comment.comments = comment.comments.map(c => this.processComment(c, currentUserId));
    }
    return comment;
  }

  toggleCommentForm(feed: FeedItem): void {
    feed.showCommentForm = !feed.showCommentForm;
    if (!feed.showCommentForm) {
      feed.commentText = '';
    }
  }

  submitComment(feed: FeedItem): void {
    if (!feed.commentText || feed.commentText.trim() === '') {
      return;
    }

    const commentData = {
      text: feed.commentText,
      parentId: feed.id
    };

    this.http.post<{ id: number; messagesLeft: number | null }>(`${environment.apiUrl}/feed/addfeed`, commentData)
      .subscribe({
        next: (response) => {
          feed.commentText = '';
          feed.showCommentForm = false;
          // Update messagesLeft from backend response (including null for verified users)
          if (response.messagesLeft !== undefined) {
            this.authService.updateMessagesLeft(response.messagesLeft);
          }
          this.loadComments(feed);
        },
        error: (error) => {
          console.error('Failed to add comment', error);
          // Check if it's a message limit error
          if (error.error?.message?.includes('Message limit reached')) {
            alert(error.error.message);
          }
        }
      });
  }

  getCommentsCount(feed: FeedItem): number {
    return feed.comments?.length || 0;
  }

  deleteComment(feed: FeedItem): void {
    if (!confirm('Are you sure you want to delete this comment? All replies will also be deleted.')) {
      return;
    }

    this.http.post(`${environment.apiUrl}/feed/deletefeed`, { id: feed.id })
      .subscribe({
        next: () => {
          // SignalR will handle removal for all clients
        },
        error: (error) => {
          console.error('Failed to delete comment', error);
          alert('Failed to delete comment');
        }
      });
  }

  canDeleteComment(feed: FeedItem): boolean {
    const currentUserId = this.authService.getUserId();
    if (!currentUserId) return false;
    // Check if current user is the comment author
    return feed.profileId === currentUserId;
  }

  getFullPhotoUrl(photoPath?: string): string {
    if (!photoPath) return '';
    if (photoPath.startsWith('http')) return photoPath;
    const baseUrl = environment.apiUrl.replace('/api', '');
    return `${baseUrl}${photoPath}`;
  }
}

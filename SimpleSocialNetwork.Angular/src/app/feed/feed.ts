import { Component, OnInit, OnDestroy, NgZone } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule, FormsModule } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { environment } from '../../environments/environment';
import { AuthService } from '../services/auth.service';
import * as signalR from '@microsoft/signalr';
import { FeedCommentComponent } from '../feed-comment/feed-comment';

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
  commentsCount?: number;
  showComments?: boolean;
  showCommentForm?: boolean;
  commentText?: string;
  commentsPage?: number;
  commentsLoading?: boolean;
  hasMoreComments?: boolean;
  commentsTotalCount?: number;
  commentsTotalPages?: number;
}

@Component({
  selector: 'app-feed',
  imports: [
    CommonModule,
    ReactiveFormsModule,
    FormsModule,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatFormFieldModule,
    MatInputModule,
    MatSnackBarModule,
    FeedCommentComponent
  ],
  templateUrl: './feed.html',
  styleUrl: './feed.css',
})
export class FeedComponent implements OnInit, OnDestroy {
  feeds: FeedItem[] = [];
  loading = true;
  postForm: FormGroup;
  posting = false;
  liking: { [key: number]: boolean } = {};
  private hubConnection?: signalR.HubConnection;
  private profileUpdateSubscription?: any;
  messagesLeft: number | null = null;
  currentPage = 1;
  pageSize = 5;
  totalCount = 0;
  totalPages = 0;

  constructor(private http: HttpClient, private fb: FormBuilder, private authService: AuthService, private ngZone: NgZone, private router: Router, private snackBar: MatSnackBar) {
    this.postForm = this.fb.group({
      text: ['', [Validators.required, Validators.maxLength(500)]]
    });
    this.messagesLeft = this.authService.getMessagesLeft();
  }

  get isPostingDisabled(): boolean {
    return !this.authService.isVerified() && this.messagesLeft !== null && this.messagesLeft <= 0;
  }

  ngOnInit(): void {
    this.loadFeed();
    this.startSignalRConnection();
    
    // Subscribe to profile updates to refresh messagesLeft
    this.profileUpdateSubscription = this.authService.profileUpdated$.subscribe(() => {
      this.messagesLeft = this.authService.getMessagesLeft();
    });

    // Fetch messagesLeft from backend on feed initialization
    if (this.authService.isAuthenticated() && !this.authService.isVerified()) {
      this.http.get<{ messagesLeft: number | null }>(`${environment.apiUrl}/profile/GetCurrentUserMessagesLeft`)
        .subscribe({
          next: (response) => {
            this.authService.updateMessagesLeft(response.messagesLeft);
          },
          error: (error) => {
            console.error('Failed to fetch messagesLeft on feed init', error);
          }
        });
    }
  }

  ngOnDestroy(): void {
    if (this.hubConnection) {
      this.hubConnection.stop();
    }
    if (this.profileUpdateSubscription) {
      this.profileUpdateSubscription.unsubscribe();
    }
  }

  private startSignalRConnection(): void {
    // Remove /api suffix for SignalR hub connection
    const hubUrl = environment.apiUrl.replace('/api', '') + '/hubs/feed';
    this.hubConnection = new signalR.HubConnectionBuilder()
      .withUrl(hubUrl, {
        accessTokenFactory: () => this.authService.getToken() || ''
      })
      .withAutomaticReconnect()
      .build();

    this.hubConnection.start()
      .then(() => console.log('SignalR Connected'))
      .catch((err: Error) => console.error('SignalR Connection Error: ', err));

    this.hubConnection.on('NewFeedPost', (feedItem: FeedItem) => {
      this.ngZone.run(() => {
        console.log('New feed post received:', feedItem);
        // Only process if it's truly a top-level post (no parentId)
        if (!feedItem.parentId) {
          // Reload current page to maintain pagination integrity
          // This ensures the new post appears correctly based on sort order
          this.loadFeed(this.currentPage);
        }
      });
    });

    this.hubConnection.on('FeedLikeUpdated', (updatedFeed: FeedItem) => {
      this.ngZone.run(() => {
        console.log('Feed like updated:', updatedFeed);
        const currentUserId = this.authService.getUserId();
        
        // Find and update the feed item (could be a top-level post or a comment)
        const index = this.feeds.findIndex(f => f.id === updatedFeed.id);
        if (index !== -1) {
          updatedFeed.isLiked = updatedFeed.likes?.some(like => like.profileId === currentUserId) || false;
          // Preserve UI state
          updatedFeed.showComments = this.feeds[index].showComments;
          updatedFeed.comments = this.feeds[index].comments;
          updatedFeed.commentsPage = this.feeds[index].commentsPage;
          updatedFeed.commentsTotalCount = this.feeds[index].commentsTotalCount;
          updatedFeed.commentsTotalPages = this.feeds[index].commentsTotalPages;
          updatedFeed.commentsLoading = this.feeds[index].commentsLoading;
          this.feeds[index] = updatedFeed;
        } else {
          // It might be a comment, search in nested comments
          this.updateNestedComment(this.feeds, updatedFeed, currentUserId);
        }
      });
    });

    this.hubConnection.on('NewComment', (comment: FeedItem) => {
      this.ngZone.run(() => {
        console.log('New comment received:', comment);
        if (comment.parentId) {
          // Find parent in top-level feeds
          const parent = this.feeds.find(f => f.id === comment.parentId);
          if (parent) {
            // Increment comment count
            parent.commentsCount = (parent.commentsCount || 0) + 1;
            parent.commentsTotalCount = (parent.commentsTotalCount || 0) + 1;
            if (parent.commentsTotalPages) {
              parent.commentsTotalPages = Math.ceil(parent.commentsTotalCount / 5);
            }
            
            // Reload current page if comments are visible
            if (parent.showComments && parent.commentsPage) {
              this.loadComments(parent, parent.commentsPage);
            }
          } else {
            // Parent might be a nested comment, search recursively
            this.updateNestedCommentCount(this.feeds, comment.parentId);
          }
        }
      });
    });

    this.hubConnection.on('FeedDeleted', (feedId: number) => {
      this.ngZone.run(() => {
        console.log('Feed deleted:', feedId);
        // Check if it's a top-level feed
        const index = this.feeds.findIndex(f => f.id === feedId);
        if (index !== -1) {
          // It's a top-level post, reload current page to maintain pagination
          this.loadFeed(this.currentPage);
        } else {
          // Remove from nested comments
          this.removeNestedComment(this.feeds, feedId);
        }
      });
    });

    this.hubConnection.on('ForceLogout', (userToken: string) => {
      this.ngZone.run(() => {
        console.log('ForceLogout received for token:', userToken);
        const currentUserToken = this.authService.getToken();
        if (currentUserToken === userToken) {
          console.log('Current user token matches, logging out...');
          this.authService.logout();
          window.location.href = '/login';
        }
      });
    });

    this.hubConnection.on('AccountDeleted', (userToken: string) => {
      this.ngZone.run(() => {
        console.log('AccountDeleted received for token:', userToken);
        const currentUserToken = this.authService.getToken();
        if (currentUserToken === userToken) {
          console.log('Current user account was deleted, redirecting to message page...');
          this.authService.logout();
          this.router.navigate(['/message'], { 
            state: { 
              message: 'Your account has been deleted by an administrator', 
              icon: 'error' 
            } 
          });
        }
      });
    });

    this.hubConnection.on('RefreshMessageLimit', () => {
      this.ngZone.run(() => {
        console.log('Message limit updated, checking if update needed...');
        // Only update if user is unverified and doesn't have 0 messages
        const currentMessagesLeft = this.authService.getMessagesLeft();
        if (!this.authService.isVerified() && currentMessagesLeft !== 0) {
          // Fetch the actual messagesLeft from backend
          this.http.get<{ messagesLeft: number | null }>(`${environment.apiUrl}/profile/GetCurrentUserMessagesLeft`)
            .subscribe({
              next: (response) => {
                console.log('Received messagesLeft from server:', response.messagesLeft);
                this.authService.updateMessagesLeft(response.messagesLeft);
                // The profileUpdated$ subscription will update messagesLeft property
              },
              error: (error) => {
                console.error('Failed to fetch messagesLeft', error);
              }
            });
        } else if (currentMessagesLeft === 0) {
          console.log('User has 0 messages left, not updating. User must verify to continue posting.');
        }
      });
    });

    this.hubConnection.on('MessageLimitUpdated', (userToken: string, newLimit: number) => {
      this.ngZone.run(() => {
        console.log('MessageLimitUpdated received for token:', userToken, 'New limit:', newLimit);
        const currentUserToken = this.authService.getToken();
        if (currentUserToken === userToken) {
          console.log('Current user message limit updated to:', newLimit);
          this.authService.updateMessagesLeft(newLimit);
          this.snackBar.open(`Your message limit has been updated to ${newLimit}`, 'Close', {
            duration: 5000,
            horizontalPosition: 'center',
            verticalPosition: 'top'
          });
        }
      });
    });

    this.hubConnection.on('UserVerificationChanged', (userToken: string, verified: boolean) => {
      this.ngZone.run(() => {
        console.log('UserVerificationChanged received for token:', userToken, 'Verified:', verified);
        const currentUserToken = this.authService.getToken();
        if (currentUserToken === userToken) {
          console.log('Current user verification status changed to:', verified);
          this.authService.updateVerified(verified);
          if (verified) {
            this.authService.updateMessagesLeft(null);
            this.snackBar.open('Your account has been verified! You now have unlimited messages.', 'Close', {
              duration: 5000,
              horizontalPosition: 'center',
              verticalPosition: 'top'
            });
          } else {
            // Fetch message limit from backend when unverified to restore the counter
            this.http.get<{ messagesLeft: number | null }>(`${environment.apiUrl}/profile/GetCurrentUserMessagesLeft`)
              .subscribe({
                next: (response) => {
                  console.log('Fetched messagesLeft after unverification:', response.messagesLeft);
                  this.authService.updateMessagesLeft(response.messagesLeft);
                  this.snackBar.open('Your account verification has been removed. Message limit restored.', 'Close', {
                    duration: 5000,
                    horizontalPosition: 'center',
                    verticalPosition: 'top'
                  });
                },
                error: (error) => {
                  console.error('Failed to fetch messagesLeft after unverification', error);
                  this.snackBar.open('Your account verification has been removed.', 'Close', {
                    duration: 5000,
                    horizontalPosition: 'center',
                    verticalPosition: 'top'
                  });
                }
              });
          }
        }
      });
    });
  }

  private updateNestedComment(items: FeedItem[], updatedItem: FeedItem, currentUserId: number | null): boolean {
    for (const item of items) {
      if (item.comments && item.comments.length > 0) {
        const index = item.comments.findIndex(c => c.id === updatedItem.id);
        if (index !== -1) {
          updatedItem.isLiked = updatedItem.likes?.some(like => like.profileId === currentUserId) || false;
          // Preserve existing nested comments and UI state
          updatedItem.comments = item.comments[index].comments;
          updatedItem.showComments = item.comments[index].showComments;
          updatedItem.showCommentForm = item.comments[index].showCommentForm;
          item.comments[index] = updatedItem;
          return true;
        }
        if (this.updateNestedComment(item.comments, updatedItem, currentUserId)) {
          return true;
        }
      }
    }
    return false;
  }

  private updateNestedCommentCount(items: FeedItem[], parentId: number): boolean {
    for (const item of items) {
      if (item.id === parentId) {
        // Increment comment count
        item.commentsCount = (item.commentsCount || 0) + 1;
        item.commentsTotalCount = (item.commentsTotalCount || 0) + 1;
        if (item.commentsTotalPages) {
          item.commentsTotalPages = Math.ceil(item.commentsTotalCount / 5);
        }
        
        // Reload current page if comments are visible
        if (item.showComments && item.commentsPage) {
          this.loadComments(item, item.commentsPage);
        }
        return true;
      }
      if (item.comments && item.comments.length > 0) {
        if (this.updateNestedCommentCount(item.comments, parentId)) {
          return true;
        }
      }
    }
    return false;
  }

  private removeNestedComment(items: FeedItem[], feedId: number): boolean {
    for (const item of items) {
      if (item.comments && item.comments.length > 0) {
        const index = item.comments.findIndex(c => c.id === feedId);
        if (index !== -1) {
          // Reload current page to maintain pagination instead of just removing
          if (item.showComments && item.commentsPage) {
            this.loadComments(item, item.commentsPage);
          } else {
            // If comments aren't visible, just update counts
            item.comments.splice(index, 1);
            if (item.commentsCount !== undefined && item.commentsCount > 0) {
              item.commentsCount--;
            }
            if (item.commentsTotalCount !== undefined && item.commentsTotalCount > 0) {
              item.commentsTotalCount--;
            }
            if (item.commentsTotalPages && item.commentsTotalCount !== undefined) {
              item.commentsTotalPages = Math.ceil(item.commentsTotalCount / 5);
            }
          }
          return true;
        }
        if (this.removeNestedComment(item.comments, feedId)) {
          return true;
        }
      }
    }
    return false;
  }

  loadFeed(page: number = 1): void {
    this.loading = true;
    this.currentPage = page;
    this.http.get<{ feeds: FeedItem[], totalCount: number, page: number, pageSize: number }>(
      `${environment.apiUrl}/feed/getfeedpaginated?page=${page}&pageSize=${this.pageSize}`
    ).subscribe({
      next: (response) => {
        const currentUserId = this.authService.getUserId();
        this.feeds = response.feeds.map(feed => ({
          ...feed,
          isLiked: feed.likes?.some(like => like.profileId === currentUserId) || false,
          comments: [],
          commentsPage: 0,
          hasMoreComments: (feed.commentsCount || 0) > 0
        }));
        this.totalCount = response.totalCount;
        this.totalPages = Math.ceil(this.totalCount / this.pageSize);
        this.loading = false;
        this.liking = {};
      },
      error: (error) => {
        console.error('Failed to load feed', error);
        this.loading = false;
        this.liking = {};
      }
    });
  }

  goToPage(page: number): void {
    if (page < 1 || page > this.totalPages) return;
    this.loadFeed(page);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  goToFirstPage(): void {
    this.goToPage(1);
  }

  goToPreviousPage(): void {
    this.goToPage(this.currentPage - 1);
  }

  goToNextPage(): void {
    this.goToPage(this.currentPage + 1);
  }

  goToLastPage(): void {
    this.goToPage(this.totalPages);
  }

  getPageNumbers(): number[] {
    const pages: number[] = [];
    const maxVisible = 5;
    let start = Math.max(1, this.currentPage - Math.floor(maxVisible / 2));
    let end = Math.min(this.totalPages, start + maxVisible - 1);
    
    if (end - start < maxVisible - 1) {
      start = Math.max(1, end - maxVisible + 1);
    }
    
    for (let i = start; i <= end; i++) {
      pages.push(i);
    }
    return pages;
  }

  createPost(): void {
    if (this.postForm.invalid || this.posting) {
      return;
    }

    this.posting = true;
    const postData = { text: this.postForm.value.text };

    this.http.post<{ id: number; messagesLeft: number | null }>(`${environment.apiUrl}/feed/addfeed`, postData)
      .subscribe({
        next: (response) => {
          this.postForm.reset();
          this.posting = false;
          // Update messagesLeft from backend response (including null for verified users)
          if (response.messagesLeft !== undefined) {
            this.authService.updateMessagesLeft(response.messagesLeft);
          }
          // Don't reload - SignalR will push the new post to all clients
        },
        error: (error) => {
          console.error('Failed to create post', error);
          this.posting = false;
          // Check if it's a message limit error
          if (error.error?.message?.includes('Message limit reached')) {
            alert(error.error.message);
          }
        }
      });
  }

  getLikesCount(feed: FeedItem): number {
    return feed.likes?.length || 0;
  }

  toggleLike(feed: FeedItem): void {
    if (this.liking[feed.id]) {
      return; // Already processing
    }

    const currentUserId = this.authService.getUserId();
    if (!currentUserId) {
      return;
    }
    
    this.liking[feed.id] = true;
    
    // Use isLiked flag to determine action
    if (feed.isLiked) {
      // Unlike - find the user's like
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
      // Like
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

  deleteFeed(feed: FeedItem): void {
    if (!confirm('Are you sure you want to delete this post? All replies will also be deleted.')) {
      return;
    }

    this.http.post(`${environment.apiUrl}/feed/deletefeed`, { id: feed.id })
      .subscribe({
        next: () => {
          // SignalR will handle removal for all clients
        },
        error: (error) => {
          console.error('Failed to delete post', error);
          alert('Failed to delete post');
        }
      });
  }

  canDeleteFeed(feed: FeedItem): boolean {
    const currentUserId = this.authService.getUserId();
    if (!currentUserId) return false;
    // Check if current user is the feed author
    return feed.profileId === currentUserId;
  }

  getFullPhotoUrl(photoPath?: string): string {
    if (!photoPath) return '';
    if (photoPath.startsWith('http')) return photoPath;
    // photoPath already includes /api prefix, so use base URL without /api
    const baseUrl = environment.apiUrl.replace('/api', '');
    return `${baseUrl}${photoPath}`;
  }

  toggleComments(feed: FeedItem): void {
    feed.showComments = !feed.showComments;
    if (feed.showComments && (!feed.comments || feed.comments.length === 0)) {
      this.loadComments(feed, 1);
    }
  }

  loadComments(feed: FeedItem, page: number = 1): void {
    if (feed.commentsLoading) return;
    
    feed.commentsLoading = true;
    feed.commentsPage = page;
    const pageSize = 5;

    this.http.get<{ comments: FeedItem[], totalCount: number }>(
      `${environment.apiUrl}/feed/getcommentspaginated/${feed.id}?page=${page}&pageSize=${pageSize}`
    ).subscribe({
      next: (response) => {
        const currentUserId = this.authService.getUserId();
        feed.comments = response.comments.map(comment => this.processComment(comment, currentUserId));
        feed.commentsTotalCount = response.totalCount;
        feed.commentsTotalPages = Math.ceil(response.totalCount / pageSize);
        feed.showComments = true;
        feed.commentsLoading = false;
        feed.hasMoreComments = feed.commentsTotalPages > page;
      },
      error: (error) => {
        console.error('Failed to load comments', error);
        feed.commentsLoading = false;
      }
    });
  }

  goToCommentPage(feed: FeedItem, page: number): void {
    if (page < 1 || (feed.commentsTotalPages && page > feed.commentsTotalPages)) {
      return;
    }
    this.loadComments(feed, page);
  }

  goToFirstCommentPage(feed: FeedItem): void {
    this.loadComments(feed, 1);
  }

  goToPreviousCommentPage(feed: FeedItem): void {
    if (feed.commentsPage && feed.commentsPage > 1) {
      this.loadComments(feed, feed.commentsPage - 1);
    }
  }

  goToNextCommentPage(feed: FeedItem): void {
    if (feed.commentsPage && feed.commentsTotalPages && feed.commentsPage < feed.commentsTotalPages) {
      this.loadComments(feed, feed.commentsPage + 1);
    }
  }

  goToLastCommentPage(feed: FeedItem): void {
    if (feed.commentsTotalPages) {
      this.loadComments(feed, feed.commentsTotalPages);
    }
  }

  getCommentPageNumbers(feed: FeedItem): number[] {
    if (!feed.commentsTotalPages) return [];
    const pages: number[] = [];
    const currentPage = feed.commentsPage || 1;
    const totalPages = feed.commentsTotalPages;
    let startPage = Math.max(1, currentPage - 2);
    let endPage = Math.min(totalPages, currentPage + 2);
    if (endPage - startPage < 4) {
      if (startPage === 1) {
        endPage = Math.min(totalPages, startPage + 4);
      } else if (endPage === totalPages) {
        startPage = Math.max(1, endPage - 4);
      }
    }
    for (let i = startPage; i <= endPage; i++) {
      pages.push(i);
    }
    return pages;
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

    this.http.post<{ id: number }>(`${environment.apiUrl}/feed/addfeed`, commentData)
      .subscribe({
        next: () => {
          feed.commentText = '';
          feed.showCommentForm = false;
          feed.showComments = true;
          // Reload comments to show new one
          this.loadComments(feed);
        },
        error: (error) => {
          console.error('Failed to add comment', error);
        }
      });
  }

  getCommentsCount(feed: FeedItem): number {
    return feed.commentsCount || 0;
  }
}

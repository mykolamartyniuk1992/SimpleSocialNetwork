import {
  Component,
  Input,
  OnInit,
  OnDestroy,
  ElementRef,
  HostListener,
  ViewChild
} from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatTooltipModule } from '@angular/material/tooltip';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';

import { environment } from '../../environments/environment';
import { AuthService } from '../services/auth.service';
import { LikesDialogComponent } from '../likes-dialog/likes-dialog.component';

interface Like {
  id: number;
  feedId: number;
  profileId: number;
  profileName?: string;
}

interface LastLike {
  profileName: string;
  token?: string;
  photoPath?: string;
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
  commentsCount?: number;
  commentsPage?: number;
  commentsLoading?: boolean;
  hasMoreComments?: boolean;
  commentsTotalCount?: number;
  commentsTotalPages?: number;

  // попап лайков
  showLikesPopup?: boolean;
  likesLoading?: boolean;
  lastLikes?: LastLike[];

  popupX?: number;
  popupY?: number;
  popupPosition?: 'top' | 'bottom';
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
    MatInputModule,
    MatTooltipModule,
    MatDialogModule
  ],
  templateUrl: './feed-comment.html',
  styleUrl: './feed-comment.css',
})
export class FeedCommentComponent implements OnInit, OnDestroy {
  @Input() comment!: FeedItem;

  // ссылка на враппер кнопки лайка (для позиционирования попапа на мобилке)
  @ViewChild('likesWrapper') likesWrapperRef!: ElementRef<HTMLDivElement>;

  liking: { [key: number]: boolean } = {};
  private profileUpdateSubscription?: any;
  messagesLeft: number | null = null;

  // --- поведение попапа ---
  isMobile =
    /Android|iPhone|iPad|iPod|Opera Mini|IEMobile|WPDesktop/i.test(
      navigator.userAgent
    );
  private likesHideTimeouts: { [id: number]: any } = {};
  private longPressTimeout: any = null;
  private longPressTriggered = false;

  constructor(
    private http: HttpClient,
    private authService: AuthService,
    private dialog: MatDialog,
    private elRef: ElementRef
  ) {
    this.messagesLeft = this.authService.getMessagesLeft();
  }

  get isPostingDisabled(): boolean {
    return (
      !this.authService.isVerified() &&
      this.messagesLeft !== null &&
      this.messagesLeft <= 0
    );
  }

  ngOnInit(): void {
    this.profileUpdateSubscription =
      this.authService.profileUpdated$.subscribe(() => {
        this.messagesLeft = this.authService.getMessagesLeft();
      });
  }

  ngOnDestroy(): void {
    if (this.profileUpdateSubscription) {
      this.profileUpdateSubscription.unsubscribe();
    }
  }

  // ---------- POPUP ЛАЙКОВ ----------

  openLikesDialog(comment: FeedItem, event: MouseEvent): void {
    event.stopPropagation();
    this.dialog.open(LikesDialogComponent, {
      width: '350px',
      data: { feedId: comment.id }
    });
  }

  /**
   * Показ попапа: на десктопе — как раньше, над кнопкой (через CSS),
   * на мобилке — считаем позицию относительно блока с лайком.
   */
  showLikesPopup(comment: FeedItem, _event?: MouseEvent | TouchEvent): void {
    // Find the like button element
    let target: HTMLElement | null = null;
    if (_event instanceof MouseEvent) {
      target = _event.target as HTMLElement;
    } else if (_event instanceof TouchEvent && _event.touches.length > 0) {
      target = _event.touches[0].target as HTMLElement;
    }
    if (!target && this.likesWrapperRef?.nativeElement) {
      target = this.likesWrapperRef.nativeElement;
    }
    if (!target) return;

    // Get bounding rect of the button/wrapper
    const rect = target.getBoundingClientRect();
    const popupWidth = 220; // Approximate popup width
    const popupHeight = 120; // Approximate popup height
    const margin = 8;
    // Attach bottom left of popup to top right of button
    let left = rect.right;
    let top = rect.top - popupHeight;
    // If not enough space above, show below (attach top left of popup to bottom right of button)
    if (top < margin) {
      top = rect.bottom;
    }
    // Clamp left to viewport
    left = Math.max(margin, Math.min(left, window.innerWidth - popupWidth - margin));
    comment.showLikesPopup = true;
    comment.popupX = left;
    comment.popupY = top;
    comment.popupPosition = top < rect.top ? 'top' : 'bottom';

    if (!comment.lastLikes) {
      comment.likesLoading = true;
      this.http
        .get<LastLike[]>(
          `${environment.apiUrl}/feed/getlastlikes/${comment.id}?count=5`
        )
        .subscribe({
          next: likes => {
            comment.lastLikes = likes;
            comment.likesLoading = false;
          },
          error: () => {
            comment.lastLikes = [];
            comment.likesLoading = false;
          }
        });
    }
  }

  hideLikesPopup(comment: FeedItem): void {
    // 📱 Mobile: не скрываем автоматически, только по клику вне
    if (this.isMobile) return;

    // 🖥 Desktop: лёгкий таймаут, чтобы успеть доехать мышкой
    if (this.likesHideTimeouts[comment.id]) {
      clearTimeout(this.likesHideTimeouts[comment.id]);
    }

    this.likesHideTimeouts[comment.id] = setTimeout(() => {
      comment.showLikesPopup = false;
      this.likesHideTimeouts[comment.id] = null;
    }, 300);
  }

  // long-press для мобильных
  onTouchStart(comment: FeedItem, event: TouchEvent): void {
    if (!this.isMobile) return;

    const target = event.target as HTMLElement;

    // если жмём внутри уже открытого попапа — игнорим
    if (target.closest('.likes-popup')) {
      return;
    }

    this.longPressTriggered = false;
    clearTimeout(this.longPressTimeout);

    this.longPressTimeout = setTimeout(() => {
      this.longPressTriggered = true;
      this.showLikesPopup(comment);
    }, 1000); // 1 секунда
  }

  onTouchEnd(comment: FeedItem, event: TouchEvent): void {
    if (!this.isMobile) return;

    const target = event.target as HTMLElement;

    // тап по попапу — не трогаем лайк
    if (target.closest('.likes-popup')) {
      clearTimeout(this.longPressTimeout);
      return;
    }

    clearTimeout(this.longPressTimeout);

    // long-press уже отработал → просто отпустили палец
    if (this.longPressTriggered) {
      return;
    }

    // короткий тап → обычный лайк
    this.toggleLike(comment);
  }

  // закрытие попапа по клику/тачу вне компонента (ТОЛЬКО мобилки)
  @HostListener('document:click', ['$event'])
  onDocumentClick(event: MouseEvent): void {
    if (!this.isMobile) return;

    const target = event.target as HTMLElement;

    if (this.elRef.nativeElement.contains(target)) {
      return;
    }

    if (this.comment.showLikesPopup) {
      this.comment.showLikesPopup = false;
    }
  }

  @HostListener('document:touchstart', ['$event'])
  onDocumentTouchStart(event: TouchEvent): void {
    if (!this.isMobile) return;

    const target = event.target as HTMLElement;

    if (this.elRef.nativeElement.contains(target)) {
      return;
    }

    if (this.comment.showLikesPopup) {
      this.comment.showLikesPopup = false;
    }
  }

  // ---------- СТАНДАРТНАЯ ЛОГИКА КОММЕНТОВ ----------

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
      const userLike = feed.likes?.find(
        like => like.profileId === currentUserId
      );
      if (!userLike) {
        console.error('Cannot find like to remove');
        this.liking[feed.id] = false;
        return;
      }

      this.http
        .post(`${environment.apiUrl}/feed/dislike`, {
          id: userLike.id,
          feedId: feed.id
        })
        .subscribe({
          next: () => {
            this.liking[feed.id] = false;
          },
          error: error => {
            console.error('Failed to unlike post', error);
            this.liking[feed.id] = false;
          }
        });
    } else {
      this.http
        .post<{ id: number; feedId: number; profileId: number }>(
          `${environment.apiUrl}/feed/like`,
          { feedId: feed.id }
        )
        .subscribe({
          next: () => {
            this.liking[feed.id] = false;
          },
          error: error => {
            console.error('Failed to like post', error);
            this.liking[feed.id] = false;
          }
        });
    }
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

    this.http
      .get<{ comments: FeedItem[]; totalCount: number }>(
        `${environment.apiUrl}/feed/getcommentspaginated/${feed.id}?page=${page}&pageSize=${pageSize}`
      )
      .subscribe({
        next: response => {
          const currentUserId = this.authService.getUserId();
          feed.comments = response.comments.map(comment =>
            this.processComment(comment, currentUserId)
          );
          feed.commentsTotalCount = response.totalCount;
          feed.commentsTotalPages = Math.ceil(
            response.totalCount / pageSize
          );
          feed.showComments = true;
          feed.commentsLoading = false;
          feed.hasMoreComments = feed.commentsTotalPages > page;
        },
        error: error => {
          console.error('Failed to load comments', error);
          feed.commentsLoading = false;
        }
      });
  }

  private processComment(
    comment: FeedItem,
    currentUserId: number | null
  ): FeedItem {
    comment.isLiked =
      comment.likes?.some(like => like.profileId === currentUserId) || false;
    if (comment.comments && comment.comments.length > 0) {
      comment.comments = comment.comments.map(c =>
        this.processComment(c, currentUserId)
      );
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

    this.http
      .post<{ id: number; messagesLeft: number | null }>(
        `${environment.apiUrl}/feed/addfeed`,
        commentData
      )
      .subscribe({
        next: response => {
          feed.commentText = '';
          feed.showCommentForm = false;
          if (response.messagesLeft !== undefined) {
            this.authService.updateMessagesLeft(response.messagesLeft);
          }
          this.loadComments(feed, 1);
        },
        error: error => {
          console.error('Failed to add comment', error);
          if (error.error?.message?.includes('Message limit reached')) {
            alert(error.error.message);
          }
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
    if (
      feed.commentsPage &&
      feed.commentsTotalPages &&
      feed.commentsPage < feed.commentsTotalPages
    ) {
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

  getCommentsCount(feed: FeedItem): number {
    return (
      feed.commentsTotalCount ||
      feed.commentsCount ||
      feed.comments?.length ||
      0
    );
  }

  deleteComment(feed: FeedItem): void {
    if (
      !confirm(
        'Are you sure you want to delete this comment? All replies will also be deleted.'
      )
    ) {
      return;
    }

    this.http
      .post(`${environment.apiUrl}/feed/deletefeed`, { id: feed.id })
      .subscribe({
        next: () => {
          // SignalR всё подправит
        },
        error: error => {
          console.error('Failed to delete comment', error);
          alert('Failed to delete comment');
        }
      });
  }

  canDeleteComment(feed: FeedItem): boolean {
    const currentUserId = this.authService.getUserId();
    if (!currentUserId) return false;
    return feed.profileId === currentUserId;
  }

  getFullPhotoUrl(photoPath?: string): string {
    if (!photoPath) return '';
    if (photoPath.startsWith('http')) return photoPath;
    const baseUrl = environment.apiUrl.replace('/api', '');
    return `${baseUrl}${photoPath}`;
  }
}

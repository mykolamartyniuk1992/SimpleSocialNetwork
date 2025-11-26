import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterModule } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';

@Component({
  selector: 'app-message',
  standalone: true,
  imports: [CommonModule, RouterModule, MatCardModule, MatButtonModule, MatIconModule],
  templateUrl: './message.component.html',
  styleUrl: './message.component.css'
})
export class MessageComponent implements OnInit {
  message: string = 'An action has occurred';
  icon: string = 'info';

  constructor(private router: Router) {
    // Get state from navigation (must be in constructor, not ngOnInit)
    const navigation = this.router.getCurrentNavigation();
    const state = navigation?.extras.state as { message?: string; icon?: string };
    
    if (state) {
      this.message = state.message || 'An action has occurred';
      this.icon = state.icon || 'info';
    }
  }

  ngOnInit() {
    // Navigation state is only available in constructor
    // If we got here without state, show default message
  }

  goToLogin() {
    this.router.navigate(['/login']);
  }

  goToRegister() {
    this.router.navigate(['/register']);
  }
}

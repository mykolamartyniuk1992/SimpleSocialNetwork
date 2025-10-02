import { Component, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-login-form',
  standalone: true,                    // можно standalone, тогда подключим как import (см. ниже вариант А)
  imports: [CommonModule, FormsModule],
  templateUrl: './login-form.html',
  styleUrls: ['./login-form.css']
})
export class LoginFormComponent {
  userName = signal('');
  password = signal('');
  error = signal<string | null>(null);

  constructor(private http: HttpClient) { }

  submit() {
    this.error.set(null);
    const dto = { userName: this.userName(), password: this.password() };
    this.http.post('/api/login', dto).subscribe({
      next: () => window.location.href = '/Feed.html',
      error: (e) => this.error.set(e?.error?.message ?? 'Login failed')
    });
  }
}

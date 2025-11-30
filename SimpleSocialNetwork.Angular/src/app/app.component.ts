
import { Component, OnInit } from '@angular/core';
import { Router, RouterOutlet } from '@angular/router';
import { HeaderComponent } from './header/header.component';
import { FooterComponent } from './footer.component';
import { environment } from '../environments/environment';
import { AuthService } from './services/auth.service';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  standalone: true,
  imports: [RouterOutlet, HeaderComponent, FooterComponent]
})
export class AppComponent implements OnInit {
  public showLayout = false;

  constructor(private router: Router, private authService: AuthService) {
    // this.router.events is an Observable that emits events when navigation happens (route changes)
    this.router.events.subscribe(() => {
      this.updateLayout();
    });
    this.updateLayout();
  }

  ngOnInit() {
    document.body.classList.add(`theme-${environment.theme}`);
    this.updateLayout();
  }

  private updateLayout() {
    const path = this.router.url;
    // Header показывается только если пользователь авторизован и не на /login или /register
    this.showLayout = this.authService.isAuthenticated() && !['/login', '/register'].includes(path);
  }
}

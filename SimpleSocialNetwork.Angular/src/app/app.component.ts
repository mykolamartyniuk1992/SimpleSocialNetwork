import { Component, OnInit } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { HeaderComponent } from './header/header.component';
import { FooterComponent } from './footer.component';
import { environment } from '../environments/environment';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  standalone: true,
  imports: [RouterOutlet, HeaderComponent, FooterComponent]
})
export class AppComponent implements OnInit {
  ngOnInit() {
    // Apply theme based on environment
    document.body.classList.add(`theme-${environment.theme}`);
  }
}

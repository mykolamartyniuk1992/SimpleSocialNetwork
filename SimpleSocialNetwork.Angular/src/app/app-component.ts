import { Component, signal } from '@angular/core';

@Component({
  selector: 'app-root',
  templateUrl: './app-component.html',
  standalone: false,
  styleUrl: './app.css'
})
export class AppComponent {
  protected readonly title = signal('SimpleSocialNetwork.Angular');
}

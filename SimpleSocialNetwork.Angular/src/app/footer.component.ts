import { Component } from '@angular/core';
import { VERSION } from '../environments/version';

@Component({
  selector: 'app-footer',
  template: `
    <footer class="footer">
      <div class="footer-content">
        <span>Version: {{ version }}</span>
      </div>
    </footer>
  `,
  styles: [`
    .footer {
      width: 100vw;
      background: #222;
      color: #fff;
      text-align: center;
      padding: 1rem 0;
      position: fixed;
      left: 0;
      bottom: 0;
      z-index: 100;
    }
    .footer-content {
      font-size: 0.95rem;
      letter-spacing: 0.05em;
    }
  `]
})
export class FooterComponent {
  version = VERSION;
}

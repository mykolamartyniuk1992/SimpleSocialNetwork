import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';

export interface FrontendConfig { apiBaseUrl: string; }

@Injectable({ providedIn: 'root' })
export class AppConfigService {
  private http = inject(HttpClient);
  private base = '';

  async load(): Promise<void> {
    try {
      // без ведущего слэша — путь будет относительным к <base href> (удобно при подкаталогах)
      const cfg = await firstValueFrom(
        this.http.get<FrontendConfig>('assets/app-config.json', { withCredentials: false })
      );
      const raw = (cfg?.apiBaseUrl ?? '').trim();

      // нормализуем (уберём хвостовой слэш)
      this.base = raw.endsWith('/') ? raw.slice(0, -1) : raw;
    } catch {
      // если файла нет/404 — считаем same-origin и работаем с относительными /api
      this.base = '';
    }
  }

  /** Сконструировать абсолютный URL для API */
  api(path: string): string {
    if (!path.startsWith('/')) path = '/' + path;
    return this.base ? `${this.base}${path}` : path; // пустая база → same-origin
  }

  get baseUrl(): string { return this.base; }
}

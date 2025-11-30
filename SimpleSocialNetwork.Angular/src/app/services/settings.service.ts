import { BehaviorSubject } from 'rxjs';
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { environment } from '../../environments/environment';

@Injectable({ providedIn: 'root' })
export class SettingsService {
  private _projectId: string | null = null;
  private _defaultMessageLimit: number = environment.defaultMessageLimit;
  private _apiUrl: string = '';
  private _configLoaded: boolean = false;

  private _connectionError$ = new BehaviorSubject<boolean>(false);
  public connectionError$ = this._connectionError$.asObservable();



  constructor(private http: HttpClient) {
    // Загрузка apiUrl из конфиг-файла assets/appconfig.json
    const localApiUrl = localStorage.getItem('apiUrl');
    if (localApiUrl) {
      this._apiUrl = localApiUrl;
      this._configLoaded = true;
    } else {
      this.loadAppConfig();
    }
  }

  private loadAppConfig(): void {
    const configFile = environment.production ? '/assets/appconfig.production.json' : '/assets/appconfig.json';
    this.http.get<{ apiUrl: string }>(configFile).subscribe({
      next: (config) => {
        this._apiUrl = config.apiUrl;
        this._configLoaded = true;
        this._connectionError$.next(false);
      },
      error: () => {
        // Не присваиваем _apiUrl и _configLoaded, если не удалось загрузить конфиг
        this._connectionError$.next(true);
      }
    });
  }
  public setConnectionError(state: boolean) {
    this._connectionError$.next(state);
  }


  get projectId(): string | null {
    return this._projectId;
  }

  get defaultMessageLimit(): number {
    return this._defaultMessageLimit;
  }

  get apiUrl(): string {
    // localStorage имеет приоритет, иначе — из appconfig.json, fallback — дефолт
    return localStorage.getItem('apiUrl') || this._apiUrl;
  }

  async loadProjectId(): Promise<void> {
    try {
      const result = await firstValueFrom(this.http.get<{ projectId: string, defaultMessageLimit?: number }>(`${this.apiUrl}/config/getprojectid`));
      this._projectId = result.projectId;
    } catch (e) {
      this._projectId = null;
    }
  }
}

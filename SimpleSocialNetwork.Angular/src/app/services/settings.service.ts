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
  }

  public initialize(): Promise<void> {
    const localApiUrl = localStorage.getItem('apiUrl');
    console.log('[SettingsService] localStorage apiUrl:', localApiUrl);
    if (localApiUrl) {
      this._apiUrl = localApiUrl;
      this._configLoaded = true;
      console.log('[SettingsService] Using apiUrl from localStorage:', this._apiUrl);
      return Promise.resolve();
    } else {
      console.log('[SettingsService] No apiUrl in localStorage, loading config...');
      return this.loadAppConfig();
    }
  }

  private async loadAppConfig(): Promise<void> {
    const configFile = environment.production ? '/assets/appconfig.production.json' : '/assets/appconfig.json';
    console.log('[SettingsService] Loading config file:', configFile, '| environment.production =', environment.production);
    
    try {
      const text = await firstValueFrom(this.http.get(configFile, { responseType: 'text' }));
      let config: any = null;
      try {
        config = JSON.parse(text);
      } catch (e) {
        console.error('[SettingsService] Failed to parse config JSON:', e, text);
        this._connectionError$.next(true);
        return;
      }
      if (!config.apiUrl) {
        console.error('[SettingsService] Config loaded but apiUrl missing:', config);
        this._connectionError$.next(true);
        return;
      }
      console.log('[SettingsService] Config loaded:', config);
      this._apiUrl = config.apiUrl;
      this._configLoaded = true;
      this._connectionError$.next(false);
    } catch (err) {
      console.error('[SettingsService] Failed to load config:', configFile, err);
      this._connectionError$.next(true);
    }
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
    const local = localStorage.getItem('apiUrl');
    if (local) {
      return local;
    }
    if (this._apiUrl) {
      return this._apiUrl;
    }
    console.warn('[SettingsService] apiUrl fallback to default (empty string)');
    return '';
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

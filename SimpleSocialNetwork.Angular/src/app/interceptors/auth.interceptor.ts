import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { AuthService } from '../services/auth.service';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  // Не инжектировать AuthService для запросов к конфигу
  if (req.url.includes('appconfig.json') || req.url.includes('appconfig.production.json')) {
    return next(req);
  }
  const authService = inject(AuthService);
  const token = authService.getToken();
  if (token) {
    const cloned = req.clone({
      setHeaders: {
        Authorization: `Bearer ${token}`
      }
    });
    return next(cloned);
  }
  return next(req);
};

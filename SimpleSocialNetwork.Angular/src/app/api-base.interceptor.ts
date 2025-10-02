import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { AppConfigService } from './app-config.service';

export const apiBaseInterceptor: HttpInterceptorFn = (req, next) => {
  if (req.url.startsWith('/api')) {
    const cfg = inject(AppConfigService);
    req = req.clone({ url: cfg.api(req.url) });
  }
  return next(req);
};

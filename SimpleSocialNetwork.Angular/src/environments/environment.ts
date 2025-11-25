export const environment = {
  production: false,
  theme: 'indigo',
  defaultMessageLimit: 100,
  get apiUrl(): string {
    // Allow admin to override API URL via localStorage
    return localStorage.getItem('apiUrl') || 'http://localhost:5003/api';
  }
};

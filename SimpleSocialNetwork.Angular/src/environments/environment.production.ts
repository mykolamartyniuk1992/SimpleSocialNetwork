export const environment = {
  production: true,
  theme: 'azure-blue',
  defaultMessageLimit: 100,
  get apiUrl(): string {
    // Allow admin to override API URL via localStorage, otherwise use relative path
    return localStorage.getItem('apiUrl') || 'http://localhost:5003/api';
  }
};

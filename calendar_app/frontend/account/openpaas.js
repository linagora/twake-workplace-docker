window.openpaas = {
    AUTH_PROVIDER: 'oidc',
    OPENPAAS_API_URL: 'https://tcalendar-side-service.twake.local',
    BASE_URL: '',
    ACCOUNT_SPA_URL: 'https://account.twake.local/account/',
    MAILTO_SPA_URL:'https://mail.twake.local',
    APP_GRID_ITEMS: '[{ "name": "Calendar", "url": "https://calendar.twake.local/calendar/" }, { "name": "Contacts", "url": "https://contacts.twake.local/contacts/" }]',
    AUTH_PROVIDER_SETTINGS: {
        authority: 'https://auth.twake.local/',
        client_id: 'openpaas',
        redirect_uri: 'https://account.twake.local/account/auth/oidc/callback',
        silent_redirect_uri: 'https://account.twake.local/account/assets/auth/silent-renew.html',
        post_logout_redirect_uri: 'https://account.twake.local/account',
        response_type: 'code',
        scope: 'openid email profile'
    }
};





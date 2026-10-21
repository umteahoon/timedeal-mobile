class AppConfig {
  // 웹 타임딜과 같은 Supabase 프로젝트·같은 서버 API를 씁니다(계정·상품·예약이 웹과 하나로 연동).
  // 빌드 시 --dart-define으로 바꿀 수 있고, 없으면 아래 운영 값을 씁니다. anon 키는 공개용 키입니다.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gkzglohnjhmypebmaaaf.supabase.co',
  );
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdremdsb2huamhteXBlYm1hYWFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY2NzU5NzEsImV4cCI6MjEwMjI1MTk3MX0.YxLiKe-jVdrini7-PjAyL7KB1MSXf6ZfeB2o5czjJmY',
  );
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://time-deal.onrender.com/api',
  );
  // 웹 버전 주소(PC로 들어오면 이쪽으로 보냄)
  static const webSiteUrl = String.fromEnvironment(
    'WEB_SITE_URL',
    defaultValue: 'https://timedeal.netlify.app',
  );
}

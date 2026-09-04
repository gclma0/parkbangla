class I18n {
  I18n(this.bn);
  bool bn;

  String t(String en, String bnText) => bn ? bnText : en;

  String get app => t('ParkBangla', 'পার্কবাংলা');
  String get tagline => t('Park like you belong here.', 'যেখানে জায়গা, সেখানেই পার্ক।');
  String get continuePhone => t('Continue with phone', 'ফোন দিয়ে চালিয়ে যান');
  String get phone => t('Phone number', 'মোবাইল নম্বর');
  String get otp => t('Enter the code', 'কোড লিখুন');
  String get demoHint => t('Demo OTP is 123456', 'ডেমো ওটিপি ১২৩৪৫৬');
  String get discover => t('Discover', 'খুঁজুন');
  String get bookings => t('Passes', 'পাস');
  String get wallet => t('Wallet', 'ওয়ালেট');
  String get profile => t('Profile', 'প্রোফাইল');
  String get renter => t('Renter', 'ভাড়াটিয়া');
  String get host => t('Host', 'হোস্ট');
  String get getPass => t('Get Commuter Pass', 'কমিউটার পাস নিন');
  String get itsAPark => t("It's a park!", 'পার্ক কনফার্ম!');
  String get skip => t('Skip', 'বাদ');
  String get book => t('Book', 'বুক');
  String get sos => t('SOS', 'এসওএস');
  String get map => t('Map', 'ম্যাপ');
  String get cards => t('Cards', 'কার্ড');
  String get checkIn => t('Check in', 'চেক-ইন');
  String get covered => t('Covered', 'ছাউনি');
  String get openAir => t('Open', 'খোলা');
}

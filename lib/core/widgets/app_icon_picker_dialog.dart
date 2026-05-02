import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class IconPickerResult {
  const IconPickerResult({
    required this.iconName,
    required this.colorHex,
  });

  final String iconName;
  final String colorHex;
}

class AppIconItem {
  const AppIconItem({
    required this.name,
    required this.label,
    required this.categoryId,
    required this.icon,
  });

  final String name;
  final String label;
  final String categoryId;
  // `Icons.*` gives `IconData` but `font_awesome_flutter` gives `FaIconData`.
  // Keep this dynamic so we can render either.
  final dynamic icon;
}

class AppIconPickerDialog extends StatefulWidget {
  const AppIconPickerDialog({
    super.key,
    required this.initialIconName,
    required this.initialColorHex,
    this.title = 'تخصيص الأيقونة',
  });

  final String initialIconName;
  final String initialColorHex;
  final String title;

  static const categoryLabels = <String, String>{
    'all': 'عام',
    'food': 'أكل',
    'transport': 'مواصلات',
    'health': 'علاج',
    'money': 'فلوس',
    'home': 'بيت',
    'fun': 'ترفيه',
    'work': 'شغل',
    'shopping': 'تسوق',
    'tech': 'تقنية',
    'other': 'أخرى',
  };

  static const categoryOrder = <String>[
    'all',
    'food',
    'transport',
    'health',
    'money',
    'home',
    'fun',
    'work',
    'shopping',
    'tech',
    'other',
  ];

  static final _baseIcons = <AppIconItem>[
    // food
    ..._iconsFor('food', [
      ('restaurant', 'وجبات', Icons.restaurant),
      ('local_pizza', 'بيتزا', Icons.local_pizza),
      ('coffee', 'قهوة', Icons.coffee),
      ('bakery', 'مخبوزات', Icons.bakery_dining),
      ('local_cafe', 'كافيه', Icons.local_cafe),
      ('icecream', 'حلويات', Icons.icecream),
      ('ramen', 'نودلز', Icons.ramen_dining),
      ('fastfood', 'وجبة سريعة', Icons.fastfood),
      ('breakfast', 'فطار', Icons.free_breakfast),
      ('egg', 'بيض', Icons.egg),
      ('cake', 'كيك', Icons.cake),
      ('lunch', 'غداء', Icons.lunch_dining),
      ('fa_utensils', 'أدوات طعام', FontAwesomeIcons.utensils),
      ('fa_burger', 'برجر', FontAwesomeIcons.burger),
      ('fa_pizza', 'بيتزا', FontAwesomeIcons.pizzaSlice),
      ('fa_apple', 'تفاح', FontAwesomeIcons.appleWhole),
      ('fa_carrot', 'خضار', FontAwesomeIcons.carrot),
      ('fa_mug', 'مشروب ساخن', FontAwesomeIcons.mugHot),
      ('fa_ice', 'آيس كريم', FontAwesomeIcons.iceCream),
      ('fa_pepper', 'بهارات', FontAwesomeIcons.pepperHot),
      ('restaurant_menu', 'منيو', Icons.restaurant_menu),
      ('food_bank', 'أكل البيت', Icons.food_bank),
      ('local_bar', 'مشروبات', Icons.local_bar),
      ('local_drink', 'عصير', Icons.local_drink),
      ('dinner_dining', 'عشاء', Icons.dinner_dining),
      ('takeout_dining', 'تيك اواي', Icons.takeout_dining),
      ('set_meal', 'وجبة كاملة', Icons.set_meal),
      ('liquor', 'مشروب', Icons.liquor),
      ('emoji_food', 'وجبات خفيفة', Icons.emoji_food_beverage),
      ('soup_kitchen', 'شوربة', Icons.soup_kitchen),
      ('fa_fish', 'سمك', FontAwesomeIcons.fish),
      ('fa_cheese', 'جبنة', FontAwesomeIcons.cheese),
      ('fa_lemon', 'ليمون', FontAwesomeIcons.lemon),
      ('fa_bacon', 'بيكون', FontAwesomeIcons.bacon),
      ('fa_bread', 'خبز', FontAwesomeIcons.breadSlice),
      ('fa_hotdog', 'هوت دوج', FontAwesomeIcons.hotdog),
      ('fa_shrimp', 'جمبري', FontAwesomeIcons.shrimp),
      ('fa_wheat', 'حبوب', FontAwesomeIcons.wheatAwn),
      ('fa_bottle', 'مياه', FontAwesomeIcons.bottleWater),
      ('fa_martini', 'كوكتيل', FontAwesomeIcons.martiniGlass),
    ]),
    // transport
    ..._iconsFor('transport', [
      ('car', 'سيارة', Icons.directions_car),
      ('bus', 'أوتوبيس', Icons.directions_bus),
      ('subway', 'مترو', Icons.directions_subway),
      ('train', 'قطار', Icons.train),
      ('flight', 'طيران', Icons.flight),
      ('bike', 'دراجة', Icons.directions_bike),
      ('taxi', 'تاكسي', Icons.local_taxi),
      ('walk', 'مشي', Icons.directions_walk),
      ('fuel', 'بنزين', Icons.local_gas_station),
      ('map', 'خرائط', Icons.map),
      ('traffic', 'مرور', Icons.traffic),
      ('ev', 'شحن', Icons.ev_station),
      ('fa_car', 'سيارة', FontAwesomeIcons.carSide),
      ('fa_bus', 'باص', FontAwesomeIcons.bus),
      ('fa_train', 'قطار', FontAwesomeIcons.train),
      ('fa_plane', 'طائرة', FontAwesomeIcons.plane),
      ('fa_ship', 'سفينة', FontAwesomeIcons.ship),
      ('fa_bike', 'عجلة', FontAwesomeIcons.bicycle),
      ('fa_motor', 'موتوسيكل', FontAwesomeIcons.motorcycle),
      ('fa_gas', 'بنزين', FontAwesomeIcons.gasPump),
      ('commute', 'تنقل', Icons.commute),
      ('car_rental', 'تأجير', Icons.car_rental),
      ('car_repair', 'صيانة', Icons.car_repair),
      ('airport_shuttle', 'شاتل', Icons.airport_shuttle),
      ('electric_bike', 'عجلة كهربا', Icons.electric_bike),
      ('electric_scooter', 'سكوتر', Icons.electric_scooter),
      ('moped', 'دراجة نارية', Icons.moped),
      ('tram', 'ترام', Icons.tram),
      ('railway', 'سكك حديد', Icons.railway_alert),
      ('local_shipping', 'شحن', Icons.local_shipping),
      ('fa_truck', 'شاحنة', FontAwesomeIcons.truck),
      ('fa_van', 'فان', FontAwesomeIcons.vanShuttle),
      ('fa_road', 'طريق', FontAwesomeIcons.road),
      ('fa_route', 'مسار', FontAwesomeIcons.route),
      ('fa_location', 'موقع', FontAwesomeIcons.locationDot),
      ('fa_map_pin', 'خريطة', FontAwesomeIcons.mapLocationDot),
      ('fa_jet', 'نفاثة', FontAwesomeIcons.jetFighter),
      ('fa_heli', 'هليكوبتر', FontAwesomeIcons.helicopter),
      ('fa_tram', 'ترام', FontAwesomeIcons.trainTram),
      ('fa_cable', 'تلفريك', FontAwesomeIcons.cableCar),
    ]),
    // health
    ..._iconsFor('health', [
      ('favorite', 'صحة', Icons.favorite),
      ('medication', 'دواء', Icons.medication),
      ('hospital', 'مستشفى', Icons.local_hospital),
      ('vaccines', 'تطعيم', Icons.vaccines),
      ('fitness', 'رياضة', Icons.fitness_center),
      ('spa', 'سبا', Icons.spa),
      ('healing', 'عناية', Icons.healing),
      ('monitor_heart', 'نبض', Icons.monitor_heart),
      ('emergency', 'طوارئ', Icons.emergency),
      ('psychology', 'دعم نفسي', Icons.psychology),
      ('bloodtype', 'تحاليل', Icons.bloodtype),
      ('health', 'رعاية', Icons.health_and_safety),
      ('fa_heart', 'نبض', FontAwesomeIcons.heartPulse),
      ('fa_pills', 'حبوب', FontAwesomeIcons.pills),
      ('fa_syringe', 'حقنة', FontAwesomeIcons.syringe),
      ('fa_stethoscope', 'سماعة طبيب', FontAwesomeIcons.stethoscope),
      ('fa_hospital', 'مستشفى', FontAwesomeIcons.hospital),
      ('fa_medkit', 'عدة إسعاف', FontAwesomeIcons.kitMedical),
      ('fa_tooth', 'أسنان', FontAwesomeIcons.tooth),
      ('fa_wheelchair', 'مساعدة', FontAwesomeIcons.wheelchair),
      ('medical_services', 'خدمات طبية', Icons.medical_services),
      ('medication_liquid', 'دواء سائل', Icons.medication_liquid),
      ('monitor_weight', 'وزن', Icons.monitor_weight),
      ('self_improvement', 'استرخاء', Icons.self_improvement),
      ('sanitizer', 'تعقيم', Icons.sanitizer),
      ('masks', 'كمامة', Icons.masks),
      ('sick', 'مرض', Icons.sick),
      ('coronavirus', 'فيروس', Icons.coronavirus),
      ('elderly', 'كبار السن', Icons.elderly),
      ('accessibility', 'احتياجات خاصة', Icons.accessibility_new),
      ('fa_capsules', 'كبسولات', FontAwesomeIcons.capsules),
      ('fa_brain', 'عقل', FontAwesomeIcons.brain),
      ('fa_dna', 'تحاليل', FontAwesomeIcons.dna),
      ('fa_eye', 'عيون', FontAwesomeIcons.eye),
      ('fa_bandaid', 'لاصق طبي', FontAwesomeIcons.bandage),
      ('fa_lungs', 'رئة', FontAwesomeIcons.lungs),
      ('fa_notes', 'ملاحظات طبية', FontAwesomeIcons.notesMedical),
      ('fa_user_doctor', 'طبيب', FontAwesomeIcons.userDoctor),
      ('fa_pump', 'مطهر', FontAwesomeIcons.pumpMedical),
      ('fa_skull', 'تشخيص', FontAwesomeIcons.skull),
    ]),
    // money
    ..._iconsFor('money', [
      ('wallet', 'محفظة', Icons.account_balance_wallet),
      ('card', 'بطاقة', Icons.credit_card),
      ('bank', 'بنك', Icons.account_balance),
      ('cash', 'نقدي', Icons.payments),
      ('receipt', 'فاتورة', Icons.receipt_long),
      ('savings', 'ادخار', Icons.savings),
      ('attach_money', 'دولار', Icons.attach_money),
      ('currency_exchange', 'تحويل', Icons.currency_exchange),
      ('price_check', 'سعر', Icons.price_check),
      ('paid', 'مدفوع', Icons.paid),
      ('account_balance_wallet', 'حساب', Icons.wallet),
      ('trending', 'استثمار', Icons.trending_up),
      ('fa_bill', 'فاتورة', FontAwesomeIcons.moneyBill),
      ('fa_bill_wave', 'دفع', FontAwesomeIcons.moneyBillWave),
      ('fa_credit', 'بطاقة', FontAwesomeIcons.creditCard),
      ('fa_bank', 'بنك', FontAwesomeIcons.buildingColumns),
      ('fa_coins', 'عملات', FontAwesomeIcons.coins),
      ('fa_wallet', 'محفظة', FontAwesomeIcons.wallet),
      ('fa_receipt', 'إيصال', FontAwesomeIcons.receipt),
      ('fa_chart', 'نمو', FontAwesomeIcons.chartLine),
      ('point_of_sale', 'نقطة بيع', Icons.point_of_sale),
      ('request_quote', 'عرض سعر', Icons.request_quote),
      ('price_change', 'تغيير سعر', Icons.price_change),
      ('monetization', 'أموال', Icons.monetization_on),
      ('pie_chart', 'نسبة', Icons.pie_chart),
      ('query_stats', 'إحصائيات', Icons.query_stats),
      (
        'account_balance_wallet_outlined',
        'حفظ فلوس',
        Icons.account_balance_wallet_outlined
      ),
      ('payments_outlined', 'دفعات', Icons.payments_outlined),
      ('wallet_giftcard', 'بطاقة هدايا', Icons.card_giftcard),
      ('receipt_long_2', 'فواتير', Icons.receipt_long),
      ('fa_piggy', 'حصالة', FontAwesomeIcons.piggyBank),
      ('fa_landmark', 'مؤسسة', FontAwesomeIcons.landmark),
      ('fa_hand_dollar', 'دخل', FontAwesomeIcons.handHoldingDollar),
      ('fa_sack', 'مبلغ', FontAwesomeIcons.sackDollar),
      ('fa_money_check', 'شيك', FontAwesomeIcons.moneyCheckDollar),
      ('fa_file_invoice', 'فاتورة ضريبية', FontAwesomeIcons.fileInvoiceDollar),
      ('fa_percent', 'نسبة', FontAwesomeIcons.percent),
      ('fa_chart_pie', 'مخطط', FontAwesomeIcons.chartPie),
      ('fa_scale', 'توازن', FontAwesomeIcons.scaleBalanced),
      ('fa_arrow_trend', 'اتجاه مالي', FontAwesomeIcons.arrowTrendUp),
    ]),
    // home
    ..._iconsFor('home', [
      ('home', 'منزل', Icons.home),
      ('bed', 'غرفة', Icons.bed),
      ('weekend', 'أثاث', Icons.weekend),
      ('kitchen', 'مطبخ', Icons.kitchen),
      ('shower', 'حمام', Icons.shower),
      ('light', 'إضاءة', Icons.lightbulb),
      ('cleaning', 'تنظيف', Icons.cleaning_services),
      ('chair', 'كرسي', Icons.chair),
      ('apartment', 'عمارة', Icons.apartment),
      ('key', 'مفتاح', Icons.key),
      ('roof', 'صيانة', Icons.home_repair_service),
      ('water', 'مياه', Icons.water_drop),
      ('fa_house', 'بيت', FontAwesomeIcons.house),
      ('fa_couch', 'كنبة', FontAwesomeIcons.couch),
      ('fa_bed', 'سرير', FontAwesomeIcons.bed),
      ('fa_bath', 'حمام', FontAwesomeIcons.bath),
      ('fa_door', 'باب', FontAwesomeIcons.doorOpen),
      ('fa_bulb', 'إضاءة', FontAwesomeIcons.lightbulb),
      ('fa_plug', 'كهرباء', FontAwesomeIcons.plug),
      ('fa_tv', 'تلفزيون', FontAwesomeIcons.tv),
      ('garage', 'جراج', Icons.garage),
      ('deck', 'بلكونة', Icons.deck),
      ('yard', 'حديقة البيت', Icons.yard),
      ('fence', 'سور', Icons.fence),
      ('window', 'شباك', Icons.window),
      ('table_restaurant', 'سفرة', Icons.table_restaurant),
      ('chair_outlined', 'كرسي', Icons.chair_outlined),
      ('bathroom', 'حمام', Icons.bathroom),
      ('bathtub', 'بانيو', Icons.bathtub),
      ('electric_bolt', 'كهرباء', Icons.electric_bolt),
      ('fa_house_user', 'أسرة', FontAwesomeIcons.houseUser),
      ('fa_house_laptop', 'بيت ذكي', FontAwesomeIcons.houseLaptop),
      ('fa_faucet', 'حنفية', FontAwesomeIcons.faucetDrip),
      ('fa_fan', 'مروحة', FontAwesomeIcons.fan),
      ('fa_sink', 'حوض', FontAwesomeIcons.sink),
      ('fa_toilet', 'تواليت', FontAwesomeIcons.toilet),
      ('fa_toolbox', 'صيانة', FontAwesomeIcons.toolbox),
      ('fa_screwdriver', 'عدة', FontAwesomeIcons.screwdriverWrench),
      ('fa_broom', 'مقشة', FontAwesomeIcons.broom),
      ('fa_pump_soap', 'صابون', FontAwesomeIcons.pumpSoap),
    ]),
    // fun
    ..._iconsFor('fun', [
      ('movie', 'فيلم', Icons.movie),
      ('music', 'موسيقى', Icons.music_note),
      ('sports_esports', 'جيمز', Icons.sports_esports),
      ('celebration', 'خروجات', Icons.celebration),
      ('beach', 'رحلة', Icons.beach_access),
      ('camera', 'تصوير', Icons.camera_alt),
      ('sports', 'رياضة', Icons.sports_soccer),
      ('park', 'حديقة', Icons.park),
      ('attractions', 'ملاهي', Icons.attractions),
      ('festival', 'حفلة', Icons.festival),
      ('theater', 'مسرح', Icons.theaters),
      ('palette', 'فن', Icons.palette),
      ('fa_game', 'جيمز', FontAwesomeIcons.gamepad),
      ('fa_music', 'موسيقى', FontAwesomeIcons.music),
      ('fa_camera', 'تصوير', FontAwesomeIcons.camera),
      ('fa_film', 'سينما', FontAwesomeIcons.film),
      ('fa_ticket', 'تذكرة', FontAwesomeIcons.ticket),
      ('fa_dice', 'ترفيه', FontAwesomeIcons.dice),
      ('fa_masks', 'مسرح', FontAwesomeIcons.masksTheater),
      ('fa_headphones', 'سماعات', FontAwesomeIcons.headphones),
      ('sports_basketball', 'سلة', Icons.sports_basketball),
      ('sports_tennis', 'تنس', Icons.sports_tennis),
      ('sports_volleyball', 'طايرة', Icons.sports_volleyball),
      ('sports_baseball', 'بيسبول', Icons.sports_baseball),
      ('sports_bar', 'مشروب', Icons.sports_bar),
      ('casino', 'كازينو', Icons.casino),
      ('theater_comedy', 'كوميديا', Icons.theater_comedy),
      ('piano', 'بيانو', Icons.piano),
      ('brush', 'رسم', Icons.brush),
      ('nightlife', 'سهر', Icons.nightlife),
      ('fa_futbol', 'كرة', FontAwesomeIcons.futbol),
      ('fa_basketball', 'سلة', FontAwesomeIcons.basketball),
      ('fa_table_tennis', 'بينج', FontAwesomeIcons.tableTennisPaddleBall),
      ('fa_volleyball', 'فولي', FontAwesomeIcons.volleyball),
      ('fa_chess', 'شطرنج', FontAwesomeIcons.chess),
      ('fa_guitar', 'جيتار', FontAwesomeIcons.guitar),
      ('fa_drum', 'درامز', FontAwesomeIcons.drum),
      ('fa_mountain', 'رحلات', FontAwesomeIcons.mountainSun),
      ('fa_person_hiking', 'هايكنج', FontAwesomeIcons.personHiking),
      ('fa_masks_2', 'عرض', FontAwesomeIcons.masksTheater),
    ]),
    // work
    ..._iconsFor('work', [
      ('work', 'شغل', Icons.work),
      ('business', 'شركة', Icons.business),
      ('meeting', 'اجتماع', Icons.groups),
      ('laptop', 'لاب توب', Icons.laptop),
      ('desk', 'مكتب', Icons.desk),
      ('assignment', 'تاسك', Icons.assignment),
      ('schedule', 'دوام', Icons.schedule),
      ('engineering', 'هندسة', Icons.engineering),
      ('support', 'خدمة', Icons.support_agent),
      ('design', 'تصميم', Icons.design_services),
      ('calculate', 'حسابات', Icons.calculate),
      ('checklist', 'قائمة', Icons.checklist),
      ('fa_briefcase', 'بريف كيس', FontAwesomeIcons.briefcase),
      ('fa_building', 'شركة', FontAwesomeIcons.building),
      ('fa_laptop', 'لاب', FontAwesomeIcons.laptopCode),
      ('fa_user_tie', 'إدارة', FontAwesomeIcons.userTie),
      ('fa_handshake', 'اتفاق', FontAwesomeIcons.handshake),
      ('fa_clipboard', 'متابعة', FontAwesomeIcons.clipboardCheck),
      ('fa_calc', 'محاسبة', FontAwesomeIcons.calculator),
      ('fa_chart_col', 'تقارير', FontAwesomeIcons.chartColumn),
      ('badge', 'هوية', Icons.badge),
      ('calendar_month', 'تقويم', Icons.calendar_month),
      ('co_present', 'عرض', Icons.co_present),
      ('analytics', 'تحليل', Icons.analytics),
      ('description', 'مستند', Icons.description),
      ('event_note', 'ملاحظات', Icons.event_note),
      ('fact_check', 'مراجعة', Icons.fact_check),
      ('feed', 'تغذية راجعة', Icons.feed),
      ('folder_copy', 'ملفات', Icons.folder_copy),
      ('manage_accounts', 'إدارة', Icons.manage_accounts),
      ('fa_user_group', 'فريق', FontAwesomeIcons.userGroup),
      ('fa_users_gear', 'موارد بشرية', FontAwesomeIcons.usersGear),
      ('fa_presentation', 'اجتماع', FontAwesomeIcons.personChalkboard),
      ('fa_clipboard_list', 'لستة مهام', FontAwesomeIcons.clipboardList),
      ('fa_business_time', 'وقت العمل', FontAwesomeIcons.businessTime),
      ('fa_file_lines', 'عقود', FontAwesomeIcons.fileLines),
      ('fa_envelope', 'إيميل', FontAwesomeIcons.envelope),
      ('fa_phone', 'اتصال', FontAwesomeIcons.phone),
      ('fa_stamp', 'اعتماد', FontAwesomeIcons.stamp),
      ('fa_chart_area', 'أداء', FontAwesomeIcons.chartArea),
    ]),
    // shopping
    ..._iconsFor('shopping', [
      ('shopping_cart', 'سلة', Icons.shopping_cart),
      ('store', 'متجر', Icons.store),
      ('shopping_bag', 'شنطة', Icons.shopping_bag),
      ('checkroom', 'ملابس', Icons.checkroom),
      ('diamond', 'اكسسوار', Icons.diamond),
      ('chair_alt', 'أثاث', Icons.chair_alt),
      ('toys', 'ألعاب', Icons.toys),
      ('watch', 'ساعة', Icons.watch),
      ('phone_iphone', 'موبايل', Icons.phone_iphone),
      ('redeem', 'هدايا', Icons.redeem),
      ('local_mall', 'مول', Icons.local_mall),
      ('sell', 'عروض', Icons.sell),
      ('fa_cart', 'سلة', FontAwesomeIcons.cartShopping),
      ('fa_bag', 'شنطة', FontAwesomeIcons.bagShopping),
      ('fa_store', 'متجر', FontAwesomeIcons.store),
      ('fa_gift', 'هدايا', FontAwesomeIcons.gift),
      ('fa_tags', 'خصم', FontAwesomeIcons.tags),
      ('fa_shirt', 'ملابس', FontAwesomeIcons.shirt),
      ('fa_gem', 'اكسسوار', FontAwesomeIcons.gem),
      ('fa_basket', 'مشتريات', FontAwesomeIcons.basketShopping),
      ('add_shopping_cart', 'إضافة للسلة', Icons.add_shopping_cart),
      ('local_offer', 'عرض', Icons.local_offer),
      ('loyalty', 'نقاط', Icons.loyalty),
      ('shopping_basket', 'سلة يد', Icons.shopping_basket),
      ('store_mall_directory', 'مول', Icons.store_mall_directory),
      ('local_grocery_store', 'بقالة', Icons.local_grocery_store),
      ('receipt', 'فاتورة', Icons.receipt),
      ('inventory_2', 'منتجات', Icons.inventory_2),
      ('styler', 'ستايل', Icons.style),
      ('sell_outlined', 'تخفيض', Icons.sell_outlined),
      ('fa_cart_plus', 'أضف شراء', FontAwesomeIcons.cartPlus),
      ('fa_cash_register', 'كاشير', FontAwesomeIcons.cashRegister),
      ('fa_bag_store', 'بوتيك', FontAwesomeIcons.shop),
      ('fa_store_slash', 'إغلاق متجر', FontAwesomeIcons.storeSlash),
      ('fa_socks', 'ملابس', FontAwesomeIcons.socks),
      ('fa_glasses', 'نظارات', FontAwesomeIcons.glasses),
      ('fa_ring', 'خواتم', FontAwesomeIcons.ring),
      ('fa_ticket_simple', 'كوبون', FontAwesomeIcons.ticketSimple),
      ('fa_shop_lock', 'شراء آمن', FontAwesomeIcons.shopLock),
      ('fa_barcode', 'باركود', FontAwesomeIcons.barcode),
    ]),
    // tech
    ..._iconsFor('tech', [
      ('smartphone', 'موبايل', Icons.smartphone),
      ('computer', 'كمبيوتر', Icons.computer),
      ('wifi', 'إنترنت', Icons.wifi),
      ('memory', 'تقنية', Icons.memory),
      ('devices', 'أجهزة', Icons.devices),
      ('cable', 'كابلات', Icons.cable),
      ('router', 'راوتر', Icons.router),
      ('headset', 'سماعة', Icons.headset),
      ('monitor', 'شاشة', Icons.monitor),
      ('keyboard', 'كيبورد', Icons.keyboard),
      ('mouse', 'ماوس', Icons.mouse),
      ('cloud', 'سحابة', Icons.cloud),
      ('fa_mobile', 'موبايل', FontAwesomeIcons.mobileScreenButton),
      ('fa_laptop_code', 'تطوير', FontAwesomeIcons.laptopCode),
      ('fa_wifi', 'واي فاي', FontAwesomeIcons.wifi),
      ('fa_chip', 'شريحة', FontAwesomeIcons.microchip),
      ('fa_server', 'سيرفر', FontAwesomeIcons.server),
      ('fa_keyboard', 'كيبورد', FontAwesomeIcons.keyboard),
      ('fa_mouse', 'ماوس', FontAwesomeIcons.computerMouse),
      ('fa_headset', 'هيدسيت', FontAwesomeIcons.headset),
      ('tablet', 'تابلت', Icons.tablet),
      ('smartwatch', 'ساعة ذكية', Icons.watch),
      ('desktop_windows', 'ديسكتوب', Icons.desktop_windows),
      ('developer_mode', 'تطوير', Icons.developer_mode),
      ('developer_board', 'لوحة', Icons.developer_board),
      ('dns', 'DNS', Icons.dns),
      ('code', 'كود', Icons.code),
      ('bug_report', 'أخطاء', Icons.bug_report),
      ('security', 'أمان', Icons.security),
      ('storage', 'تخزين', Icons.storage),
      ('fa_tablet', 'تابلت', FontAwesomeIcons.tabletScreenButton),
      ('fa_desktop', 'شاشة', FontAwesomeIcons.desktop),
      ('fa_code_branch', 'نسخ', FontAwesomeIcons.codeBranch),
      ('fa_terminal', 'طرفية', FontAwesomeIcons.terminal),
      ('fa_database', 'قاعدة بيانات', FontAwesomeIcons.database),
      ('fa_cloud', 'سحابة', FontAwesomeIcons.cloud),
      ('fa_usb', 'USB', FontAwesomeIcons.usb),
      ('fa_print', 'طباعة', FontAwesomeIcons.print),
      ('fa_satellite', 'اتصال', FontAwesomeIcons.satelliteDish),
      ('fa_robot', 'روبوت', FontAwesomeIcons.robot),
    ]),
    // other
    ..._iconsFor('other', [
      ('category', 'عام', Icons.category),
      ('star', 'مميز', Icons.star),
      ('bookmark', 'مرجع', Icons.bookmark),
      ('bolt', 'سريع', Icons.bolt),
      ('pets', 'حيوانات', Icons.pets),
      ('school', 'تعليم', Icons.school),
      ('child_care', 'أطفال', Icons.child_care),
      ('card_giftcard', 'هدية', Icons.card_giftcard),
      ('local_florist', 'زهور', Icons.local_florist),
      ('public', 'عام', Icons.public),
      ('event', 'مناسبة', Icons.event),
      ('more_horiz', 'أخرى', Icons.more_horiz),
      ('fa_star', 'نجمة', FontAwesomeIcons.star),
      ('fa_bookmark', 'علامة', FontAwesomeIcons.bookmark),
      ('fa_bell', 'تنبيه', FontAwesomeIcons.bell),
      ('fa_book', 'كتاب', FontAwesomeIcons.book),
      ('fa_paw', 'حيوانات', FontAwesomeIcons.paw),
      ('fa_tree', 'طبيعة', FontAwesomeIcons.tree),
      ('fa_globe', 'عالمي', FontAwesomeIcons.globe),
      ('fa_circle', 'عام', FontAwesomeIcons.circleDot),
      ('auto_awesome', 'مميز', Icons.auto_awesome),
      ('explore', 'استكشاف', Icons.explore),
      ('flag', 'علم', Icons.flag),
      ('forest', 'غابة', Icons.forest),
      ('rocket_launch', 'انطلاق', Icons.rocket_launch),
      ('volunteer', 'مساعدة', Icons.volunteer_activism),
      ('celeb_other', 'حدث', Icons.celebration),
      ('lightning', 'نشاط', Icons.flash_on),
      ('travel', 'رحلات', Icons.travel_explore),
      ('waves', 'بحر', Icons.waves),
      ('fa_flag', 'علم', FontAwesomeIcons.flag),
      ('fa_compass', 'اتجاه', FontAwesomeIcons.compass),
      ('fa_feather', 'خفيف', FontAwesomeIcons.feather),
      ('fa_seedling', 'نمو', FontAwesomeIcons.seedling),
      ('fa_fire', 'نشاط', FontAwesomeIcons.fire),
      ('fa_moon', 'ليل', FontAwesomeIcons.moon),
      ('fa_sun', 'نهار', FontAwesomeIcons.sun),
      ('fa_anchor', 'ثابت', FontAwesomeIcons.anchor),
      ('fa_paperclip', 'ملحق', FontAwesomeIcons.paperclip),
      ('fa_wand', 'سحري', FontAwesomeIcons.wandMagicSparkles),
    ]),
  ];

  static List<AppIconItem> _iconsFor(
    String categoryId,
    List<(String, String, dynamic)> data,
  ) {
    return data
        .map((e) => AppIconItem(
              name: e.$1,
              label: e.$2,
              categoryId: categoryId,
              icon: e.$3,
            ))
        .toList();
  }

  static List<AppIconItem> iconsForCategory(String categoryId) {
    if (categoryId == 'all') {
      return List<AppIconItem>.from(_baseIcons);
    }
    return _baseIcons.where((icon) => icon.categoryId == categoryId).toList();
  }

  static dynamic iconForName(String name) {
    for (final item in _baseIcons) {
      if (item.name == name) return item.icon;
    }
    for (final item in _baseIcons) {
      if (name.contains(item.name)) return item.icon;
    }
    const legacyMap = <String, dynamic>{
      'PiggyBank': Icons.savings,
      'Wallet2': Icons.account_balance_wallet,
      'UtensilsCrossed': Icons.restaurant,
      'BriefcaseBusiness': Icons.work,
      'HeartPulse': Icons.favorite,
      'ShoppingCart': Icons.shopping_cart,
      'CarFront': Icons.directions_car,
      'Home': Icons.home,
    };
    return legacyMap[name] ?? Icons.category;
  }

  static Widget iconWidgetForName(
    String name, {
    Color? color,
    double size = 24,
  }) {
    final icon = iconForName(name);
    final iconData = icon as IconData;
    if (iconData.fontPackage == 'font_awesome_flutter') {
      return FaIcon(iconData, color: color, size: size);
    }
    return Icon(iconData, color: color, size: size);
  }

  static IconData iconDataForName(String name) {
    final icon = iconForName(name);
    // This method is kept for older call sites that still expect IconData.
    // If the icon is a FontAwesome one, callers should migrate to
    // `iconWidgetForName` to avoid runtime type issues.
    if (icon is IconData) return icon;
    return Icons.category;
  }

  static Future<IconPickerResult?> show(
    BuildContext context, {
    required String initialIconName,
    required String initialColorHex,
    String title = 'تخصيص الأيقونة',
  }) {
    return showDialog<IconPickerResult>(
      context: context,
      builder: (_) => Dialog(
        child: AppIconPickerDialog(
          initialIconName: initialIconName,
          initialColorHex: initialColorHex,
          title: title,
        ),
      ),
    );
  }

  @override
  State<AppIconPickerDialog> createState() => _AppIconPickerDialogState();
}

class _AppIconPickerDialogState extends State<AppIconPickerDialog> {
  late String _selectedCategoryId;
  late String _selectedIconName;
  late Color _selectedColor;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _selectedIconName = widget.initialIconName;
    _selectedColor = _hexToColor(widget.initialColorHex);
    _selectedCategoryId = 'all';
  }

  @override
  Widget build(BuildContext context) {
    final icons = AppIconPickerDialog.iconsForCategory(_selectedCategoryId);
    final theme = Theme.of(context);
    // final colorHex = _colorToHex(_selectedColor);
    const contentHeight = 320.0;
    final dialogWidth = math.min(
      720.0,
      MediaQuery.of(context).size.width - 32.0,
    );
    return SizedBox(
      width: dialogWidth,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            _topSegment(theme),
            const SizedBox(height: 12),
            if (_step == 0) ...[
              SizedBox(
                height: 45,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppIconPickerDialog
                                .categoryLabels[_selectedCategoryId] ??
                            _selectedCategoryId,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'فلتر الكاتيجوري',
                      onPressed: _openCategorySheet,
                      icon: const Icon(Icons.filter_alt_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: contentHeight,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                  color: theme.colorScheme.surface,
                ),
                child: _selectedCategoryId == 'all'
                    ? CustomScrollView(
                        slivers: [
                          ...AppIconPickerDialog.categoryOrder
                              .where((id) => id != 'all')
                              .expand((categoryId) {
                            final groupIcons =
                                AppIconPickerDialog.iconsForCategory(
                                    categoryId);
                            return [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    6,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        AppIconPickerDialog
                                                .categoryLabels[categoryId] ??
                                            categoryId,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          height: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        height: 2,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.65),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final item = groupIcons[index];
                                    final active =
                                        _selectedIconName == item.name;
                                    return InkWell(
                                      onTap: () => setState(
                                          () => _selectedIconName = item.name),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.45),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: active
                                                ? theme.colorScheme.primary
                                                : theme
                                                    .colorScheme.outlineVariant
                                                    .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: Center(
                                          child: AppIconPickerDialog
                                              .iconWidgetForName(
                                            item.name,
                                            size: 24,
                                            color: active
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  childCount: groupIcons.length,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 1,
                                ),
                              ),
                            ];
                          }),
                        ],
                      )
                    : GridView.builder(
                        itemCount: icons.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, index) {
                          final item = icons[index];
                          final active = _selectedIconName == item.name;
                          return InkWell(
                            onTap: () =>
                                setState(() => _selectedIconName = item.name),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: active
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Center(
                                child: AppIconPickerDialog.iconWidgetForName(
                                  item.name,
                                  size: 24,
                                  color: active
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // const SizedBox(height: 12),
              const SizedBox(height: 12),
              Center(
                child: FilledButton(
                  onPressed: () => setState(() => _step = 1),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(180, 50),
                  ),
                  child: const Text('التالي'),
                ),
              ),
            ] else ...[
              SizedBox(
                height: 45,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'معاينة الأيقونة',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: AppIconPickerDialog.iconWidgetForName(
                          _selectedIconName,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: contentHeight,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ColorBoxPicker(
                        color: _selectedColor,
                        onChanged: (color) =>
                            setState(() => _selectedColor = color),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    IconPickerResult(
                      iconName: _selectedIconName,
                      colorHex: _colorToHex(_selectedColor),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(180, 50),
                  ),
                  child: const Text('تأكيد'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openCategorySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final sheetHeight = MediaQuery.of(context).size.height * 0.55;
        return SafeArea(
          child: SizedBox(
            height: sheetHeight.clamp(320.0, 520.0),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: AppIconPickerDialog.categoryOrder.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final id = AppIconPickerDialog.categoryOrder[index];
                final selected = id == _selectedCategoryId;
                return Card(
                  color: selected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12)
                      : Theme.of(context).colorScheme.surface,
                  child: ListTile(
                    title: Text(
                      AppIconPickerDialog.categoryLabels[id] ?? id,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    trailing: selected ? const Icon(Icons.check) : null,
                    onTap: () {
                      setState(() => _selectedCategoryId = id);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _topSegment(ThemeData theme) {
    return SizedBox(
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: _step == 0
                      ? AlignmentDirectional.centerStart
                      : AlignmentDirectional.centerEnd,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E7F5C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _step = 0),
                        child: Center(
                          child: Text(
                            'اختيار الأيقونة',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _step == 0
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _step = 1),
                        child: Center(
                          child: Text(
                            'اختيار اللون',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _step == 1
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | value);
  }

  String _colorToHex(Color color) {
    final red = (color.r * 255.0).round().clamp(0, 255);
    final green = (color.g * 255.0).round().clamp(0, 255);
    final blue = (color.b * 255.0).round().clamp(0, 255);
    return '#'
        '${red.toRadixString(16).padLeft(2, '0')}'
        '${green.toRadixString(16).padLeft(2, '0')}'
        '${blue.toRadixString(16).padLeft(2, '0')}';
  }
}

// class _ColorWheel extends StatelessWidget {
//   const _ColorWheel({
//     required this.color,
//     required this.onChanged,
//   });

//   final Color color;
//   final ValueChanged<Color> onChanged;

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: 190,
//       height: 190,
//       child: _ColorWheelGesture(
//         color: color,
//         onChanged: onChanged,
//       ),
//     );
//   }
// }

class _ColorWheelGesture extends StatefulWidget {
  const _ColorWheelGesture({
    required this.color,
    required this.onChanged,
  });

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  State<_ColorWheelGesture> createState() => _ColorWheelGestureState();
}

class _ColorWheelGestureState extends State<_ColorWheelGesture> {
  void _update(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final vector = localPosition - center;
    final radius = size.shortestSide / 2;
    final distance = vector.distance.clamp(0, radius);
    final saturation = (distance / radius).clamp(0.0, 1.0);
    final hue =
        ((math.atan2(vector.dy, vector.dx) * 180 / math.pi) + 360) % 360;
    final color = HSVColor.fromAHSV(1, hue, saturation, 1).toColor();
    widget.onChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(widget.color);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final radius = size.shortestSide / 2;
        final angle = hsv.hue * math.pi / 180;
        final distance = hsv.saturation * radius;
        final center = Offset(size.width / 2, size.height / 2);
        final knob = Offset(
          center.dx + math.cos(angle) * distance,
          center.dy + math.sin(angle) * distance,
        );
        return GestureDetector(
          onPanDown: (d) => _update(d.localPosition, size),
          onPanUpdate: (d) => _update(d.localPosition, size),
          child: Stack(
            children: [
              CustomPaint(
                size: size,
                painter: _WheelPainter(),
              ),
              Positioned(
                left: knob.dx - 10,
                top: knob.dy - 10,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = Paint()
      ..shader = SweepGradient(
        colors: List.generate(
          13,
          (index) =>
              HSVColor.fromAHSV(1, (index * 30).toDouble(), 1, 1).toColor(),
        ),
      ).createShader(rect);
    canvas.drawCircle(center, radius, sweep);

    final radial = Paint()
      ..shader = const RadialGradient(
        colors: [Colors.white, Colors.transparent],
        stops: [0, 1],
      ).createShader(rect);
    canvas.drawCircle(center, radius, radial);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ColorBoxPicker extends StatelessWidget {
  const _ColorBoxPicker({
    required this.color,
    required this.onChanged,
  });

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanDown: (d) => _update(d.localPosition, constraints.biggest),
          onPanUpdate: (d) => _update(d.localPosition, constraints.biggest),
          child: CustomPaint(
            size: Size.infinite,
            painter: _ColorBoxPainter(),
          ),
        );
      },
    );
  }

  void _update(Offset pos, Size size) {
    final x = (pos.dx / size.width).clamp(0.0, 1.0);
    final y = (pos.dy / size.height).clamp(0.0, 1.0);

    final hue = x * 360;
    final saturation = 1.0;
    final value = 1 - y;

    final color = HSVColor.fromAHSV(1, hue, saturation, value).toColor();
    onChanged(color);
  }
}

class _ColorBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Gradient أفقي (Hue)
    final hueGradient = LinearGradient(
      colors: List.generate(
        7,
        (i) => HSVColor.fromAHSV(1, i * 60, 1, 1).toColor(),
      ),
    );

    final paint = Paint()..shader = hueGradient.createShader(rect);
    canvas.drawRect(rect, paint);

    // Gradient رأسي (Brightness)
    final shade = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
      ).createShader(rect);

    canvas.drawRect(rect, shade);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

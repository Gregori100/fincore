import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Catálogo curado de colores e íconos para categorías.
///
/// **Historia**: los slugs originales (`academic-cap`, `arrow-trending-up`,
/// etc.) fueron contrato compartido con el backend Laravel y la Vue web
/// usando HeroIcons. Tras el pivote del 2026-06-12 a app Flutter local-first
/// single-user, esa paridad ya no es necesaria: el backend vive en la rama
/// `legacy/web-and-online-flutter` y no participa del runtime actual.
///
/// **Convención post-pivote**: los slugs nuevos pueden usar nombres directos
/// de Material Icons (kebab-case). Los 30 originales se mantienen sin
/// renombrar para no romper categorías existentes en BDs ya creadas. Si en el
/// futuro Diego decide sync con backend, decidir entonces si renombrar o
/// mapear de forma bidireccional.

class CategoryColor {
  final String slug;
  final Color color;
  final String label;
  const CategoryColor({required this.slug, required this.color, required this.label});
}

class CategoryIcon {
  final String slug;
  final IconData icon;
  final String label;
  const CategoryIcon({required this.slug, required this.icon, required this.label});
}

const List<CategoryColor> kCategoryColors = <CategoryColor>[
  CategoryColor(slug: 'blue', color: FincoreColors.categoryBlue, label: 'Azul'),
  CategoryColor(slug: 'green', color: FincoreColors.categoryGreen, label: 'Verde'),
  CategoryColor(slug: 'red', color: FincoreColors.categoryRed, label: 'Rojo'),
  CategoryColor(slug: 'orange', color: FincoreColors.categoryOrange, label: 'Naranja'),
  CategoryColor(slug: 'purple', color: FincoreColors.categoryPurple, label: 'Púrpura'),
  CategoryColor(slug: 'pink', color: FincoreColors.categoryPink, label: 'Rosa'),
  CategoryColor(slug: 'teal', color: FincoreColors.categoryTeal, label: 'Verde-azul'),
  CategoryColor(slug: 'yellow', color: FincoreColors.categoryYellow, label: 'Amarillo'),
  CategoryColor(slug: 'indigo', color: FincoreColors.categoryIndigo, label: 'Índigo'),
  CategoryColor(slug: 'gray', color: FincoreColors.categoryGray, label: 'Gris'),
];

const List<CategoryIcon> kCategoryIcons = <CategoryIcon>[
  CategoryIcon(slug: 'academic-cap', icon: Icons.school_outlined, label: 'Educación'),
  CategoryIcon(slug: 'arrow-trending-up', icon: Icons.trending_up, label: 'Tendencia'),
  CategoryIcon(slug: 'banknotes', icon: Icons.payments_outlined, label: 'Billetes'),
  CategoryIcon(slug: 'bolt', icon: Icons.bolt_outlined, label: 'Energía'),
  CategoryIcon(slug: 'book-open', icon: Icons.menu_book_outlined, label: 'Libros'),
  CategoryIcon(slug: 'briefcase', icon: Icons.work_outline, label: 'Trabajo'),
  CategoryIcon(slug: 'cake', icon: Icons.cake_outlined, label: 'Cumpleaños'),
  CategoryIcon(slug: 'checkroom', icon: Icons.checkroom_outlined, label: 'Ropa'),
  CategoryIcon(slug: 'computer-desktop', icon: Icons.desktop_windows_outlined, label: 'Computadora'),
  CategoryIcon(slug: 'content-cut', icon: Icons.content_cut_outlined, label: 'Peluquería'),
  CategoryIcon(slug: 'credit-card', icon: Icons.credit_card_outlined, label: 'Tarjeta'),
  CategoryIcon(slug: 'currency-dollar', icon: Icons.attach_money_outlined, label: 'Dinero'),
  CategoryIcon(slug: 'device-phone-mobile', icon: Icons.phone_iphone_outlined, label: 'Móvil'),
  CategoryIcon(slug: 'directions-car', icon: Icons.directions_car_outlined, label: 'Auto'),
  CategoryIcon(slug: 'film', icon: Icons.movie_outlined, label: 'Películas'),
  CategoryIcon(slug: 'fire', icon: Icons.local_fire_department_outlined, label: 'Fuego'),
  CategoryIcon(slug: 'fitness-center', icon: Icons.fitness_center_outlined, label: 'Gimnasio'),
  CategoryIcon(slug: 'flight', icon: Icons.flight_outlined, label: 'Viajes'),
  CategoryIcon(slug: 'gift', icon: Icons.card_giftcard_outlined, label: 'Regalo'),
  CategoryIcon(slug: 'globe-alt', icon: Icons.public_outlined, label: 'Internet'),
  CategoryIcon(slug: 'heart', icon: Icons.favorite_outline, label: 'Salud'),
  CategoryIcon(slug: 'home', icon: Icons.home_outlined, label: 'Hogar'),
  CategoryIcon(slug: 'key', icon: Icons.key_outlined, label: 'Renta'),
  CategoryIcon(slug: 'light-bulb', icon: Icons.lightbulb_outline, label: 'Idea'),
  CategoryIcon(slug: 'local-bar', icon: Icons.local_bar_outlined, label: 'Bar'),
  CategoryIcon(slug: 'local-cafe', icon: Icons.local_cafe_outlined, label: 'Café'),
  CategoryIcon(slug: 'local-pharmacy', icon: Icons.local_pharmacy_outlined, label: 'Farmacia'),
  CategoryIcon(slug: 'local-taxi', icon: Icons.local_taxi_outlined, label: 'Taxi'),
  CategoryIcon(slug: 'map', icon: Icons.map_outlined, label: 'Mapa'),
  CategoryIcon(slug: 'musical-note', icon: Icons.music_note_outlined, label: 'Música'),
  CategoryIcon(slug: 'paint-brush', icon: Icons.brush_outlined, label: 'Arte'),
  CategoryIcon(slug: 'pets', icon: Icons.pets_outlined, label: 'Mascotas'),
  CategoryIcon(slug: 'receipt-long', icon: Icons.receipt_long_outlined, label: 'Recibo'),
  CategoryIcon(slug: 'restaurant', icon: Icons.restaurant_outlined, label: 'Restaurante'),
  CategoryIcon(slug: 'savings', icon: Icons.savings_outlined, label: 'Ahorro'),
  CategoryIcon(slug: 'shopping-bag', icon: Icons.shopping_bag_outlined, label: 'Compras'),
  CategoryIcon(slug: 'shopping-cart', icon: Icons.shopping_cart_outlined, label: 'Carrito'),
  CategoryIcon(slug: 'sparkles', icon: Icons.auto_awesome_outlined, label: 'Brillos'),
  CategoryIcon(slug: 'sports-esports', icon: Icons.sports_esports_outlined, label: 'Videojuegos'),
  CategoryIcon(slug: 'star', icon: Icons.star_outline, label: 'Favorito'),
  CategoryIcon(slug: 'subscriptions', icon: Icons.subscriptions_outlined, label: 'Suscripciones'),
  CategoryIcon(slug: 'tag', icon: Icons.label_outline, label: 'Etiqueta'),
  CategoryIcon(slug: 'trophy', icon: Icons.emoji_events_outlined, label: 'Trofeo'),
  CategoryIcon(slug: 'truck', icon: Icons.local_shipping_outlined, label: 'Transporte'),
  CategoryIcon(slug: 'water-drop', icon: Icons.water_drop_outlined, label: 'Agua'),
  CategoryIcon(slug: 'wifi', icon: Icons.wifi_outlined, label: 'Wi-Fi'),
  CategoryIcon(slug: 'wrench', icon: Icons.build_outlined, label: 'Herramienta'),
  CategoryIcon(slug: 'wrench-screwdriver', icon: Icons.handyman_outlined, label: 'Mantenimiento'),
];

/// Fallback al gris + tag genérico si llega un slug desconocido (versión vieja
/// de la app contra catálogo más reciente, o restore de respaldo con slug que
/// se removió del catálogo curado).
const Color kFallbackCategoryColor = FincoreColors.categoryGray;
const IconData kFallbackCategoryIcon = Icons.label_outline;

Color colorBySlug(String? slug) {
  if (slug == null) return kFallbackCategoryColor;
  for (final c in kCategoryColors) {
    if (c.slug == slug) return c.color;
  }
  return kFallbackCategoryColor;
}

IconData iconBySlug(String? slug) {
  if (slug == null) return kFallbackCategoryIcon;
  for (final i in kCategoryIcons) {
    if (i.slug == slug) return i.icon;
  }
  return kFallbackCategoryIcon;
}

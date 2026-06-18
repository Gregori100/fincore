import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

/// Catálogo curado de colores e íconos para categorías.
///
/// Los slugs son **contrato compartido** con el backend
/// (`backend/app/Domain/Finance/Catalog/CategoryDefaults.php`) y con la Vue
/// (`frontend/src/constants/categoryCatalog.js`). Cambiar un slug aquí implica
/// actualizar las otras fuentes y migrar categorías existentes.
///
/// Iconos: mapeo de los HeroIcons usados en Vue a Material Icons equivalentes.
/// No buscamos paridad pixel-perfect; sí semántica consistente.

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
  CategoryIcon(slug: 'computer-desktop', icon: Icons.desktop_windows_outlined, label: 'Computadora'),
  CategoryIcon(slug: 'credit-card', icon: Icons.credit_card_outlined, label: 'Tarjeta'),
  CategoryIcon(slug: 'currency-dollar', icon: Icons.attach_money_outlined, label: 'Dinero'),
  CategoryIcon(slug: 'device-phone-mobile', icon: Icons.phone_iphone_outlined, label: 'Móvil'),
  CategoryIcon(slug: 'film', icon: Icons.movie_outlined, label: 'Películas'),
  CategoryIcon(slug: 'fire', icon: Icons.local_fire_department_outlined, label: 'Fuego'),
  CategoryIcon(slug: 'gift', icon: Icons.card_giftcard_outlined, label: 'Regalo'),
  CategoryIcon(slug: 'globe-alt', icon: Icons.public_outlined, label: 'Internet'),
  CategoryIcon(slug: 'heart', icon: Icons.favorite_outline, label: 'Salud'),
  CategoryIcon(slug: 'home', icon: Icons.home_outlined, label: 'Hogar'),
  CategoryIcon(slug: 'light-bulb', icon: Icons.lightbulb_outline, label: 'Idea'),
  CategoryIcon(slug: 'map', icon: Icons.map_outlined, label: 'Mapa'),
  CategoryIcon(slug: 'musical-note', icon: Icons.music_note_outlined, label: 'Música'),
  CategoryIcon(slug: 'paint-brush', icon: Icons.brush_outlined, label: 'Arte'),
  CategoryIcon(slug: 'shopping-bag', icon: Icons.shopping_bag_outlined, label: 'Compras'),
  CategoryIcon(slug: 'shopping-cart', icon: Icons.shopping_cart_outlined, label: 'Carrito'),
  CategoryIcon(slug: 'sparkles', icon: Icons.auto_awesome_outlined, label: 'Brillos'),
  CategoryIcon(slug: 'star', icon: Icons.star_outline, label: 'Favorito'),
  CategoryIcon(slug: 'tag', icon: Icons.label_outline, label: 'Etiqueta'),
  CategoryIcon(slug: 'trophy', icon: Icons.emoji_events_outlined, label: 'Trofeo'),
  CategoryIcon(slug: 'truck', icon: Icons.local_shipping_outlined, label: 'Transporte'),
  CategoryIcon(slug: 'wrench', icon: Icons.build_outlined, label: 'Herramienta'),
  CategoryIcon(slug: 'wrench-screwdriver', icon: Icons.handyman_outlined, label: 'Mantenimiento'),
];

/// Fallback al gris + tag genérico si llega un slug desconocido (versión vieja
/// de la app contra backend con catálogo más reciente).
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

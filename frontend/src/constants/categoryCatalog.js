/**
 * Catálogo curado de colores e iconos para categorías.
 *
 * Los slugs son contrato compartido con el backend
 * (`backend/app/Domain/Finance/Catalog/CategoryDefaults.php`).
 * Cambiar un slug aquí implica actualizar también la fuente backend
 * y migrar las categorías existentes si las hay.
 */
import {
  AcademicCapIcon,
  ArrowTrendingUpIcon,
  BanknotesIcon,
  BoltIcon,
  BookOpenIcon,
  BriefcaseIcon,
  CakeIcon,
  ComputerDesktopIcon,
  CreditCardIcon,
  CurrencyDollarIcon,
  DevicePhoneMobileIcon,
  FilmIcon,
  FireIcon,
  GiftIcon,
  GlobeAltIcon,
  HeartIcon,
  HomeIcon,
  LightBulbIcon,
  MapIcon,
  MusicalNoteIcon,
  PaintBrushIcon,
  ShoppingBagIcon,
  ShoppingCartIcon,
  SparklesIcon,
  StarIcon,
  TagIcon,
  TrophyIcon,
  TruckIcon,
  WrenchIcon,
  WrenchScrewdriverIcon,
} from '@heroicons/vue/24/outline'

export const COLORS = [
  { slug: 'blue', cssVar: '--color-category-blue', label: 'Azul' },
  { slug: 'green', cssVar: '--color-category-green', label: 'Verde' },
  { slug: 'red', cssVar: '--color-category-red', label: 'Rojo' },
  { slug: 'orange', cssVar: '--color-category-orange', label: 'Naranja' },
  { slug: 'purple', cssVar: '--color-category-purple', label: 'Púrpura' },
  { slug: 'pink', cssVar: '--color-category-pink', label: 'Rosa' },
  { slug: 'teal', cssVar: '--color-category-teal', label: 'Verde-azul' },
  { slug: 'yellow', cssVar: '--color-category-yellow', label: 'Amarillo' },
  { slug: 'indigo', cssVar: '--color-category-indigo', label: 'Índigo' },
  { slug: 'gray', cssVar: '--color-category-gray', label: 'Gris' },
]

export const ICONS = [
  { slug: 'shopping-bag', component: ShoppingBagIcon, label: 'Bolsa' },
  { slug: 'shopping-cart', component: ShoppingCartIcon, label: 'Carrito' },
  { slug: 'truck', component: TruckIcon, label: 'Camión' },
  { slug: 'home', component: HomeIcon, label: 'Casa' },
  { slug: 'bolt', component: BoltIcon, label: 'Rayo' },
  { slug: 'light-bulb', component: LightBulbIcon, label: 'Foco' },
  { slug: 'film', component: FilmIcon, label: 'Cine' },
  { slug: 'musical-note', component: MusicalNoteIcon, label: 'Música' },
  { slug: 'heart', component: HeartIcon, label: 'Corazón' },
  { slug: 'academic-cap', component: AcademicCapIcon, label: 'Graduación' },
  { slug: 'book-open', component: BookOpenIcon, label: 'Libro' },
  { slug: 'globe-alt', component: GlobeAltIcon, label: 'Globo' },
  { slug: 'map', component: MapIcon, label: 'Mapa' },
  { slug: 'gift', component: GiftIcon, label: 'Regalo' },
  { slug: 'cake', component: CakeIcon, label: 'Pastel' },
  { slug: 'device-phone-mobile', component: DevicePhoneMobileIcon, label: 'Teléfono' },
  { slug: 'computer-desktop', component: ComputerDesktopIcon, label: 'Computadora' },
  { slug: 'fire', component: FireIcon, label: 'Fuego' },
  { slug: 'paint-brush', component: PaintBrushIcon, label: 'Pincel' },
  { slug: 'sparkles', component: SparklesIcon, label: 'Brillo' },
  { slug: 'briefcase', component: BriefcaseIcon, label: 'Maletín' },
  { slug: 'arrow-trending-up', component: ArrowTrendingUpIcon, label: 'Tendencia' },
  { slug: 'credit-card', component: CreditCardIcon, label: 'Tarjeta' },
  { slug: 'banknotes', component: BanknotesIcon, label: 'Billetes' },
  { slug: 'currency-dollar', component: CurrencyDollarIcon, label: 'Dólar' },
  { slug: 'trophy', component: TrophyIcon, label: 'Trofeo' },
  { slug: 'star', component: StarIcon, label: 'Estrella' },
  { slug: 'wrench', component: WrenchIcon, label: 'Llave' },
  { slug: 'wrench-screwdriver', component: WrenchScrewdriverIcon, label: 'Herramientas' },
  { slug: 'tag', component: TagIcon, label: 'Etiqueta' },
]

/** Devuelve el componente Vue del icono según slug; fallback a TagIcon. */
export function iconBySlug(slug) {
  return ICONS.find((i) => i.slug === slug)?.component ?? TagIcon
}

/** Devuelve la CSS var del color según slug; fallback a gray. */
export function cssVarBySlug(slug) {
  return COLORS.find((c) => c.slug === slug)?.cssVar ?? '--color-category-gray'
}

import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pantalla de Ayuda accesible desde Settings.
/// Sprint `flutter-onboarding-for-testers-v1`.
///
/// FAQ corto en formato de 6 `ExpansionTile` en una sola pantalla
/// scrolleable. Textos hardcoded en español, sin i18n. Diseñado para
/// que los testers entiendan los conceptos del dominio sin tener que
/// preguntarle a Diego.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FincoreColors.canvas,
      appBar: AppBar(
        title: const Text('Ayuda'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Acceso al tour de bienvenida (modo review). Permite repasar
          // las 3 slides del onboarding original sin afectar nada del
          // estado de la app.
          _ReplayTourTile(
            onTap: () => context.push('/onboarding/review'),
          ),
          const SizedBox(height: 16),
          const _FaqTile(
            title: '¿Qué tipos de movimientos hay?',
            body:
                'FinCore tiene 5 tipos de movimientos:\n\n'
                '• Ingreso: dinero que entra a una cuenta (sueldo, cobranzas).\n'
                '• Gasto: dinero que sale de una cuenta de efectivo o débito.\n'
                '• Cargo a tarjeta: compra con tarjeta de crédito; aumenta la deuda.\n'
                '• Pago de tarjeta: pago de la deuda de una tarjeta de crédito '
                  'con efectivo o débito.\n'
                '• Transferencia: movimiento de dinero entre dos cuentas propias '
                  '(efectivo o débito).\n\n'
                'Las transferencias y pagos de tarjeta NO cuentan como gasto '
                'en los reportes — son movimientos internos.',
          ),
          const _FaqTile(
            title: '¿Qué significan BO, DE y CR?',
            body:
                'Son los 3 indicadores del Dashboard:\n\n'
                '• BO (Bolsa total): suma de saldos de las cuentas de efectivo y débito.\n'
                '• DE (Deuda total): suma de saldos pendientes de las tarjetas de crédito.\n'
                '• CR (Crédito disponible): saldo libre en las tarjetas '
                  '(límite − deuda).\n\n'
                'Se calculan automáticamente a partir de los movimientos. '
                'No requieren actualización manual.',
          ),
          const _FaqTile(
            title: '¿Cómo se calculan los reportes?',
            body:
                'En /reports hay 10 pestañas:\n\n'
                '• Gasto por categoría: suma de los gastos del período '
                  'agrupados por categoría, ordenados de mayor a menor.\n'
                '• Cashflow mensual: ingresos vs gastos por mes en el rango '
                  'seleccionado.\n'
                '• Top movimientos: los movimientos individuales más grandes '
                  'del período.\n'
                '• Saldo a fecha: cómo estaban las cuentas (BO/DE/CR) en una '
                  'fecha pasada, con delta vs hoy.\n'
                '• Promedio mensual: gasto promedio prorrateado al día actual '
                  'de los últimos N meses, comparado con el mes en curso.\n'
                '• Estado de tarjetas: estado actual de cada tarjeta de '
                  'crédito activa — deuda, % usado del límite, disponible, '
                  'próximo corte, próximo pago, pago mínimo estimado.\n'
                '• Presupuestos: progreso del mes en curso por categoría '
                  'con presupuesto definido — gastado, % usado, disponible, '
                  'y estado OK/Warning/Excedido.\n'
                '• Ingreso por categoría: suma de los ingresos del período '
                  'agrupados por categoría, con drill-down por bucket para '
                  'ver los movimientos exactos.\n'
                '• Calendario: vista mensual con marcadores por día según '
                  'el tipo de movimiento (verde ingreso, rojo gasto, azul '
                  'movimiento interno). Tap en un día abre la lista de los '
                  'movimientos exactos de ese día.\n'
                '• Heatmap anual: año completo estilo GitHub con intensidad '
                  'de color por día según el gasto total (solo expense + '
                  'gasto a tarjeta). Los 5 niveles se calculan por cuartiles '
                  'relativos al año. A diferencia del calendario (que '
                  'detalla el mes por tipo de movimiento), el heatmap '
                  'muestra el año por intensidad de gasto. Tap en un día '
                  'abre los gastos exactos.',
          ),
          const _FaqTile(
            title: '¿Cómo se define un presupuesto?',
            body:
                'Los presupuestos son mensuales y se definen por categoría:\n\n'
                '1. Ir a Configuración → Categorías (o desde el dashboard).\n'
                '2. Tocar la categoría a presupuestar (debe ser de tipo Gasto '
                  'o Ambos — las de Ingreso no aceptan presupuesto).\n'
                '3. Llenar el campo "Presupuesto mensual" con el monto.\n'
                '4. Guardar.\n\n'
                'La categoría aparece en la pestaña "Presupuestos" de /reports '
                'con el progreso del mes en curso. El límite es recurrente '
                'mensual (se reinicia cada primer día del mes calendario). '
                'El valor \$ 0 significa "meta de no gastar en esta categoría" '
                '— cualquier gasto se marca como excedido.',
          ),
          const _FaqTile(
            title: '¿Cómo funciona la sugerencia automática de categoría?',
            body:
                'Cuando se registra un movimiento nuevo, la app busca si ya '
                'existe una descripción parecida en el historial. Si encuentra '
                'coincidencia (aunque sea parcial, con un movimiento previo '
                'del mismo tipo), pre-selecciona la categoría que se usó '
                'aquella vez. Aparece un chip "✨ Sugerida" debajo del '
                'selector de categoría.\n\n'
                'Si la sugerencia no es correcta, basta con cambiarla '
                'manualmente y la app respeta esa elección — no vuelve a '
                'sugerir en ese formulario.',
          ),
          const _FaqTile(
            title: '¿Qué son las vistas guardadas?',
            body:
                'En /entries es posible filtrar los movimientos por fecha, '
                'tipo, cuenta, categoría y monto. Si se usa una combinación '
                'frecuente (ej: "todos los gastos del mes en la cuenta de '
                'débito"), se puede guardar como vista con un nombre.\n\n'
                'Después basta con tocar el ícono de marcador en /entries y '
                'cargarla con un toque. Sirve para no repetir la configuración '
                'cada vez.',
          ),
          const _FaqTile(
            title: '¿Cómo hacer respaldo y por qué importa?',
            body:
                'La app es 100% local: los datos viven en el celular, sin '
                'servidor. Si se pierde el celular, se formatea o se '
                'desinstala la app por error, se pierde todo.\n\n'
                'Para protegerse, hay que exportar un respaldo desde '
                'Configuración → Respaldo → "Exportar respaldo". Se genera '
                'un archivo JSON que se puede compartir con uno mismo '
                '(Drive, correo, etc.).\n\n'
                'Para restaurar, usar "Importar respaldo" en la misma '
                'sección. Recomendado: exportar cada 1-2 semanas.',
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String title;
  final String body;

  const _FaqTile({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: FincoreColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FincoreColors.border),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              title,
              style: const TextStyle(
                color: FincoreColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            iconColor: FincoreColors.accent,
            collapsedIconColor: FincoreColors.textSubtle,
            childrenPadding:
                const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  body,
                  style: const TextStyle(
                    color: FincoreColors.textSubtle,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tile destacado al principio de Ayuda para reabrir el tour de
/// bienvenida. Navega a `/onboarding/review` (modo repeat) — la vista
/// se ve igual que el primer arranque pero no afecta nada del estado.
class _ReplayTourTile extends StatelessWidget {
  final VoidCallback onTap;

  const _ReplayTourTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FincoreColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        // Mismo patrón que BaseCard: sin ripple animado para evitar el
        // parpadeo residual al volver con pop desde /onboarding/review.
        splashFactory: NoSplash.splashFactory,
        highlightColor: FincoreColors.canvas.withValues(alpha: 0.4),
        hoverColor: FincoreColors.canvas.withValues(alpha: 0.2),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: FincoreColors.accent.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FincoreColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.play_circle_outline,
                  color: FincoreColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ver tour de bienvenida',
                      style: TextStyle(
                        color: FincoreColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Repaso de las 3 slides del primer arranque.',
                      style: TextStyle(
                        color: FincoreColors.textSubtle,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                excludeSemantics: true,
                child: const Icon(
                  Icons.chevron_right,
                  color: FincoreColors.textSubtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

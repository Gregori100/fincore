import 'package:fincore/theme/fincore_colors.dart';
import 'package:flutter/material.dart';

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
        children: const [
          _FaqTile(
            title: '¿Qué tipos de movimientos hay?',
            body:
                'FinCore tiene 5 tipos de movimientos:\n\n'
                '• Ingreso: dinero que entra a una cuenta (sueldo, cobranzas).\n'
                '• Gasto: dinero que sale de una cuenta de efectivo o débito.\n'
                '• Cargo a tarjeta: compra con tarjeta de crédito; sube tu deuda.\n'
                '• Pago de tarjeta: pagás deuda de una tarjeta de crédito con '
                  'efectivo o débito.\n'
                '• Transferencia: movés plata entre dos cuentas tuyas '
                  '(efectivo o débito).\n\n'
                'Las transferencias y pagos de tarjeta NO cuentan como gasto '
                'en los reportes — son movimientos internos.',
          ),
          _FaqTile(
            title: '¿Qué significan BO, DE y CR?',
            body:
                'Son los 3 indicadores del Dashboard:\n\n'
                '• BO (Bolsa total): suma de saldos de tus cuentas de efectivo y débito.\n'
                '• DE (Deuda total): suma de saldos pendientes de tus tarjetas de crédito.\n'
                '• CR (Crédito disponible): cuánto te queda libre en tus tarjetas '
                  '(límite − deuda).\n\n'
                'Se calculan automáticamente a partir de tus movimientos. No '
                'tenés que actualizarlos manualmente.',
          ),
          _FaqTile(
            title: '¿Cómo se calculan los reportes?',
            body:
                'En /reports tenés 5 tabs:\n\n'
                '• Gasto por categoría: suma de tus gastos del período '
                  'agrupados por categoría, ordenados de mayor a menor.\n'
                '• Cashflow mensual: ingresos vs gastos por mes en el rango '
                  'que elijas.\n'
                '• Top movimientos: los movimientos individuales más grandes '
                  'del período.\n'
                '• Saldo a fecha: cómo estaban tus cuentas (BO/DE/CR) a una '
                  'fecha pasada, con delta vs hoy.\n'
                '• Promedio mensual: gasto promedio prorrateado al día actual '
                  'de los últimos N meses, comparado con el mes en curso.',
          ),
          _FaqTile(
            title: '¿Cómo funciona la sugerencia automática de categoría?',
            body:
                'Cuando registrás un movimiento nuevo, la app busca si ya '
                'usaste una descripción parecida antes. Si encuentra match '
                '(coincide aunque sea parcialmente con un movimiento previo '
                'del mismo tipo), te pre-selecciona la categoría que usaste '
                'aquella vez. Vas a ver un chip "✨ Sugerida" debajo del '
                'selector de categoría.\n\n'
                'Si la sugerencia no es correcta, cambiala manualmente y la '
                'app respeta tu elección — no vuelve a sugerir en ese form.',
          ),
          _FaqTile(
            title: '¿Qué son las vistas guardadas?',
            body:
                'En /entries podés filtrar tus movimientos por fecha, tipo, '
                'cuenta, categoría y monto. Si usás una combinación seguido '
                '(ej: "todos los gastos del mes en mi cuenta de débito"), '
                'la podés guardar como vista con nombre.\n\n'
                'Después tappeás el ícono de bookmark en /entries y la '
                'cargás con un tap. Sirve para no repetir la configuración '
                'cada vez.',
          ),
          _FaqTile(
            title: '¿Cómo hacer backup y por qué importa?',
            body:
                'La app es 100% local: tus datos viven en tu cel, sin '
                'servidor. Si perdés el cel, lo formateás o desinstalás la '
                'app por error, perdés todo.\n\n'
                'Para protegerte, exportá un respaldo desde Settings → '
                'Respaldo → "Exportar respaldo". Te genera un archivo JSON '
                'que podés compartir con vos mismo (Drive, email, etc).\n\n'
                'Para restaurar, usá "Importar respaldo" en la misma sección. '
                'Recomendado: exportar cada 1-2 semanas.',
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

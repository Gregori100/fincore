# Resumen ejecutivo — Respaldos

## Qué se implementó

La capacidad de **descargar un respaldo** de toda la información financiera (cuentas, categorías y movimientos) en un archivo, y **volver a aplicarlo** después. Aplicar un respaldo reemplaza el estado actual: borra lo que haya y restaura exactamente lo del archivo. Es la red de seguridad natural del hard reset y además permite mover los datos entre cuentas o dispositivos.

Vive en `/settings`, sección "Respaldos": un botón para descargar y otro para aplicar (subiendo el archivo y confirmando con la contraseña).

## Impacto esperado

- **Cierra el riesgo del hard reset**: ahora el borrado total deja de ser un puente sin retorno — basta descargar un respaldo antes.
- **Portabilidad**: el respaldo de una cuenta se puede aplicar en otra (los identificadores se regeneran y todo queda asignado al usuario que importa).
- **Sin cambios en lo existente**: feature aditivo, no toca el esquema ni los flujos actuales.

## Riesgos o pendientes relevantes

- El archivo es texto plano (sin cifrar): el usuario debe resguardarlo.
- En "reemplazo total" las categorías que ya existían y no están en el archivo se conservan (unión); documentado, ajustable si se quiere fidelidad estricta.
- El modo "merge" (agregar solo cuentas nuevas) se pospuso a v2 por decisión de simplicidad.
- Recorrido manual en el navegador pendiente de hacer; revisión de rama (`branch-quality-review`) recomendada antes del merge.

## Estado de pruebas

- Backend: 295/295 (20 nuevos del feature, incluido el ciclo export→reset→import que verifica saldos idénticos con delta 0.00).
- Frontend: 49/49 (sin regresión).
- Manual: pendiente.

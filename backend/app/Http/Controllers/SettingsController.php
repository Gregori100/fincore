<?php

namespace App\Http\Controllers;

use App\Domain\Finance\Actions\ExportUserData;
use App\Domain\Finance\Actions\HardResetUserData;
use App\Domain\Finance\Actions\ImportUserData;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class SettingsController extends Controller
{
    /**
     * Hard reset: borra físicamente movimientos, cuentas adicionales y plan del
     * usuario. Requiere confirmar con la contraseña actual (acción destructiva e
     * irreversible). El endpoint está scoped por sanctum + verified, así que solo
     * el dueño autenticado puede resetear su propia cuenta.
     */
    public function hardReset(Request $request)
    {
        $data = $request->validate([
            'password' => 'required|string',
            'mode' => ['sometimes', 'string', Rule::in(HardResetUserData::MODES)],
        ]);

        if (! Hash::check($data['password'], $request->user()->password)) {
            throw ValidationException::withMessages([
                'password' => 'La contraseña no es correcta.',
            ]);
        }

        $mode = $data['mode'] ?? HardResetUserData::MODE_FULL;
        $result = HardResetUserData::execute($request->user()->id, $mode);

        return response()->json([
            'message' => 'Cuenta restablecida',
            ...$result,
        ]);
    }

    /**
     * Genera el respaldo del dominio financiero del usuario como JSON. El
     * frontend lo convierte en un archivo descargable.
     */
    public function exportData(Request $request)
    {
        return response()->json(ExportUserData::execute($request->user()->id));
    }

    /**
     * Aplica un respaldo en modo reemplazo total: vacía la cuenta y restaura el
     * contenido del archivo. Acción destructiva → exige confirmar con la
     * contraseña actual, igual que el hard reset.
     */
    public function importData(Request $request)
    {
        $data = $request->validate([
            'password' => 'required|string',
            'backup' => 'required|array',
        ]);

        if (! Hash::check($data['password'], $request->user()->password)) {
            throw ValidationException::withMessages([
                'password' => 'La contraseña no es correcta.',
            ]);
        }

        $result = ImportUserData::execute($request->user()->id, $data['backup']);

        return response()->json([
            'message' => 'Respaldo aplicado',
            ...$result,
        ]);
    }
}

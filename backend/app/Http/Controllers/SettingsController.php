<?php

namespace App\Http\Controllers;

use App\Domain\Finance\Actions\HardResetUserData;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
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
        $request->validate([
            'password' => 'required|string',
        ]);

        if (! Hash::check($request->input('password'), $request->user()->password)) {
            throw ValidationException::withMessages([
                'password' => 'La contraseña no es correcta.',
            ]);
        }

        $result = HardResetUserData::execute($request->user()->id);

        return response()->json([
            'message' => 'Cuenta restablecida',
            ...$result,
        ]);
    }
}

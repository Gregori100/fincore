<?php

namespace App\Http\Controllers;

use App\Domain\Finance\Plan\Actions\BulkCreatePlannedEvents;
use App\Domain\Finance\Plan\Actions\ClearPlannedEvents;
use App\Domain\Finance\Plan\Actions\CreatePlannedEvent;
use App\Domain\Finance\Plan\Actions\CreatePlannedEventOverride;
use App\Domain\Finance\Plan\Actions\DeletePlannedEvent;
use App\Domain\Finance\Plan\Actions\DeletePlannedEventOverride;
use App\Domain\Finance\Plan\Actions\UpdatePlannedEvent;
use App\Domain\Finance\Plan\Actions\UpdatePlannedEventOverride;
use App\Domain\Finance\Plan\Services\PlanProjectionService;
use App\Models\PlannedEvent;
use Illuminate\Http\Request;

class PlanController extends Controller
{
    public function listEvents(Request $request)
    {
        $events = PlannedEvent::where('user_id', $request->user()->id)
            ->with(['origin', 'destination', 'category', 'overrides'])
            ->orderBy('start_date')
            ->get();

        return response()->json(['events' => $events]);
    }

    public function createEvent(Request $request)
    {
        $data = $request->validate([
            'kind' => 'required|string',
            'amount' => 'required|numeric|gt:0',
            'account_origin_id' => 'sometimes|nullable|uuid',
            'account_destination_id' => 'sometimes|nullable|uuid',
            'category_id' => 'sometimes|nullable|uuid|exists:categories,id',
            'description' => 'sometimes|nullable|string|max:200',
            'recurrence_type' => 'required|string',
            'recurrence_day' => 'sometimes|nullable|integer',
            'start_date' => 'required|date',
            'end_date' => 'sometimes|nullable|date',
        ]);

        $event = CreatePlannedEvent::execute($request->user()->id, $data);

        return response()->json([
            'message' => 'Evento planeado creado',
            'event' => $event->fresh(['origin', 'destination', 'category', 'overrides']),
        ], 201);
    }

    public function bulkCreateEvents(Request $request)
    {
        $data = $request->validate([
            'events' => 'required|array|min:1',
            'events.*.kind' => 'required|string',
            'events.*.amount' => 'required|numeric|gt:0',
            'events.*.account_origin_id' => 'sometimes|nullable|uuid',
            'events.*.account_destination_id' => 'sometimes|nullable|uuid',
            'events.*.category_id' => 'sometimes|nullable|uuid|exists:categories,id',
            'events.*.description' => 'sometimes|nullable|string|max:200',
            'events.*.recurrence_type' => 'required|string',
            'events.*.recurrence_day' => 'sometimes|nullable|integer',
            'events.*.start_date' => 'required|date',
            'events.*.end_date' => 'sometimes|nullable|date',
        ]);

        $result = BulkCreatePlannedEvents::execute($request->user()->id, $data['events']);

        return response()->json([
            'message' => "{$result['created']} eventos creados",
            'created' => $result['created'],
        ], 201);
    }

    public function updateEvent(Request $request, string $id)
    {
        $data = $request->validate([
            'amount' => 'sometimes|numeric|gt:0',
            'account_origin_id' => 'sometimes|nullable|uuid',
            'account_destination_id' => 'sometimes|nullable|uuid',
            'category_id' => 'sometimes|nullable|uuid|exists:categories,id',
            'description' => 'sometimes|nullable|string|max:200',
            'recurrence_type' => 'sometimes|string',
            'recurrence_day' => 'sometimes|nullable|integer',
            'start_date' => 'sometimes|date',
            'end_date' => 'sometimes|nullable|date',
        ]);

        $result = UpdatePlannedEvent::execute($request->user()->id, $id, $data);

        return response()->json([
            'message' => 'Evento planeado actualizado',
            'event' => $result['event'],
            'removed_overrides' => $result['removed_overrides'],
        ]);
    }

    public function deleteEvent(Request $request, string $id)
    {
        DeletePlannedEvent::execute($request->user()->id, $id);

        return response()->json(['message' => 'Evento planeado eliminado']);
    }

    public function createOverride(Request $request, string $eventId)
    {
        $data = $request->validate([
            'occurrence_date' => 'required|date',
            'amount' => 'sometimes|nullable|numeric|gt:0',
            'is_skipped' => 'sometimes|boolean',
        ]);

        $override = CreatePlannedEventOverride::execute($request->user()->id, $eventId, $data);

        return response()->json([
            'message' => 'Override creado',
            'override' => $override,
        ], 201);
    }

    public function updateOverride(Request $request, string $id)
    {
        $data = $request->validate([
            'amount' => 'sometimes|nullable|numeric|gt:0',
            'is_skipped' => 'sometimes|boolean',
        ]);

        $override = UpdatePlannedEventOverride::execute($request->user()->id, $id, $data);

        return response()->json([
            'message' => 'Override actualizado',
            'override' => $override,
        ]);
    }

    public function deleteOverride(Request $request, string $id)
    {
        DeletePlannedEventOverride::execute($request->user()->id, $id);

        return response()->json(['message' => 'Override eliminado']);
    }

    public function projection(Request $request)
    {
        $service = new PlanProjectionService($request->user()->id);

        return response()->json($service->project());
    }

    public function clearEvents(Request $request)
    {
        $deleted = ClearPlannedEvents::execute($request->user()->id);

        return response()->json([
            'message' => 'Plan limpiado',
            'deleted' => $deleted,
        ]);
    }
}

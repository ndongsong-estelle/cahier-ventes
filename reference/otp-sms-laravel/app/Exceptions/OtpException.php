<?php

namespace App\Exceptions;

use Exception;
use Illuminate\Http\JsonResponse;

class OtpException extends Exception
{
    public function __construct(string $message, private int $status = 422)
    {
        parent::__construct($message);
    }

    public function render(): JsonResponse
    {
        return response()->json(['message' => $this->getMessage()], $this->status);
    }
}

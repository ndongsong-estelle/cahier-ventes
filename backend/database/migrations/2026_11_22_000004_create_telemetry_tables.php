<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('events', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->uuid('device_id')->nullable();
            $table->string('name', 40);
            $table->json('props')->nullable();
            $table->timestamp('occurred_at');
            $table->timestamp('occurred_at_corrected');
            $table->timestamp('received_at');
            $table->index(['user_id', 'occurred_at_corrected']);
        });

        Schema::create('questions', function (Blueprint $table) {
            $table->string('id', 40)->primary();
            $table->string('text');
            $table->string('kind', 10);
            $table->json('choices')->nullable();
            $table->unsignedSmallInteger('after_days')->default(0);
            $table->boolean('active')->default(true);
            $table->timestamps();
        });

        Schema::create('answers', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('question_id', 40)->index();
            $table->string('value', 40)->nullable();
            $table->text('text')->nullable();
            $table->timestamp('occurred_at_corrected');
        });

        Schema::create('app_errors', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->nullable()->constrained()->cascadeOnDelete();
            $table->uuid('device_id')->nullable();
            $table->string('app_version', 30)->nullable();
            $table->text('message');
            $table->text('stack')->nullable();
            $table->timestamp('occurred_at_corrected');
            $table->timestamp('received_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('app_errors');
        Schema::dropIfExists('answers');
        Schema::dropIfExists('questions');
        Schema::dropIfExists('events');
    }
};

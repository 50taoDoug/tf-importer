# SSM Parameter Module

Models an existing SSM parameter while preserving its value, metadata, and
tags for import-only brownfield plans.

The `value` input is sensitive. Generated parameter values remain runtime data
and must not be committed.

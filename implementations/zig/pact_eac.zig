const std = @import("std");

const SemanticValidationResult = bool;
const SemanticValue = union(enum) { integer: i64, text: []const u8, text_collection: []const []const u8, missing: void };
const SemanticFieldPath = []const u8;
const SemanticOperatorName = []const u8;
const SemanticEvidence = []const u8;
const SemanticValidation = *const fn (SemanticValue) SemanticValidationResult;

fn validateTypeIsInteger(value: SemanticValue) SemanticValidationResult { return value == .integer; }
fn validateValueIsAtLeastMinimum(value: SemanticValue, minimum: SemanticValue) SemanticValidationResult { return value.integer >= minimum.integer; }
fn validateValueIsAtMostMaximum(value: SemanticValue, maximum: SemanticValue) SemanticValidationResult { return value.integer <= maximum.integer; }
fn compareValuesAreEqual(left: SemanticValue, right: SemanticValue) SemanticValidationResult { return std.meta.eql(left, right); }
fn compareLeftValueIsLessThanOrEqualToRightValue(left: SemanticValue, right: SemanticValue) SemanticValidationResult { return left.integer <= right.integer; }
fn compareCollectionContainsValue(value: SemanticValue, collection: SemanticValue) SemanticValidationResult { for (collection.text_collection) |candidate| { if (std.mem.eql(u8, candidate, value.text)) return true; } return false; }

const ArithmeticExpression = struct { add: []const SemanticFieldPath = &.{}, sub: []const SemanticFieldPath = &.{} };
const PolicyRule = struct { all_of: []const PolicyRule = &.{}, field: ?SemanticFieldPath = null, expr: ?ArithmeticExpression = null, op: SemanticOperatorName, value: SemanticValue };
const PolicyCheck = struct { check_id: []const u8, rule: PolicyRule };
const Mandate = struct { checks: []const PolicyCheck };
const PolicyEvaluationCheck = struct { check_id: []const u8, result: []const u8, evidence_ref: SemanticEvidence };
const SemanticContext = struct { transaction: std.StringHashMap(SemanticValue), inputs: std.StringHashMap(SemanticValue) };

fn splitFieldPathIntoNamespaceAndKey(path: SemanticFieldPath) struct { namespace: []const u8, key: []const u8 } { const split_index = std.mem.indexOfScalar(u8, path, '.') orelse path.len; return .{ .namespace = path[0..split_index], .key = path[split_index + 1 ..] }; }
fn resolveFieldPathFromSemanticContext(context: *const SemanticContext, path: SemanticFieldPath) SemanticValue { const parts = splitFieldPathIntoNamespaceAndKey(path); if (std.mem.eql(u8, parts.namespace, "transaction")) return context.transaction.get(parts.key) orelse .missing; if (std.mem.eql(u8, parts.namespace, "inputs")) return context.inputs.get(parts.key) orelse .missing; return .missing; }
fn addResolvedFieldsFromSemanticContext(context: *const SemanticContext, fields: []const SemanticFieldPath) SemanticValue { var total: i64 = 0; for (fields) |field| total += resolveFieldPathFromSemanticContext(context, field).integer; return .{ .integer = total }; }
fn evaluateArithmeticExpression(context: *const SemanticContext, expression: ArithmeticExpression) SemanticValue { if (expression.add.len > 0) return addResolvedFieldsFromSemanticContext(context, expression.add); return .missing; }
fn evaluatePolicyRuleAgainstSemanticContext(context: *const SemanticContext, rule: PolicyRule) struct { passed: SemanticValidationResult, evidence: SemanticEvidence } { if (rule.all_of.len > 0) { for (rule.all_of) |child| if (!evaluatePolicyRuleAgainstSemanticContext(context, child).passed) return .{ .passed = false, .evidence = "all_of child failed" }; return .{ .passed = true, .evidence = "all_of children passed" }; } const actual = if (rule.expr) |expression| evaluateArithmeticExpression(context, expression) else resolveFieldPathFromSemanticContext(context, rule.field.?); if (std.mem.eql(u8, rule.op, "lte")) return .{ .passed = compareLeftValueIsLessThanOrEqualToRightValue(actual, rule.value), .evidence = "semantic rule evaluated" }; if (std.mem.eql(u8, rule.op, "in")) return .{ .passed = compareCollectionContainsValue(actual, rule.value), .evidence = "semantic rule evaluated" }; return .{ .passed = compareValuesAreEqual(actual, rule.value), .evidence = "semantic rule evaluated" }; }

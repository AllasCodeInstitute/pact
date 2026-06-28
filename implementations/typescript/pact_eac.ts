type SemanticTypeName = string & { readonly semanticTypeName: unique symbol };
type SemanticOperatorName = string & { readonly semanticOperatorName: unique symbol };
type SemanticFieldPath = string & { readonly semanticFieldPath: unique symbol };
type SemanticEvidence = string & { readonly semanticEvidence: unique symbol };
type SemanticCheckIdentifier = string & { readonly semanticCheckIdentifier: unique symbol };
type SemanticValidationResult = boolean & { readonly semanticValidationResult: unique symbol };
type SemanticValue = number | string | readonly string[] | undefined;
type SemanticContext = Readonly<Record<string, Readonly<Record<string, SemanticValue>>>>;
type SemanticValidation = (value: SemanticValue) => SemanticValidationResult;
type SemanticPredicate = (left: SemanticValue, right: SemanticValue) => SemanticValidationResult;

const declareSemanticValidationResult = (result: boolean): SemanticValidationResult => result as SemanticValidationResult;
export const validateTypeIsInteger: SemanticValidation = value => declareSemanticValidationResult(Number.isInteger(value));
export const validateValueIsAtLeastMinimum = (minimum: number): SemanticValidation => value => declareSemanticValidationResult(typeof value === 'number' && value >= minimum);
export const validateValueIsAtMostMaximum = (maximum: number): SemanticValidation => value => declareSemanticValidationResult(typeof value === 'number' && value <= maximum);
export const composeAllValidationsMustPass = (...validations: readonly SemanticValidation[]): SemanticValidation => value => declareSemanticValidationResult(validations.every(validateCurrentRule => validateCurrentRule(value)));
export const validateIntegerRange = (minimum: number, maximum: number): SemanticValidation => composeAllValidationsMustPass(validateTypeIsInteger, validateValueIsAtLeastMinimum(minimum), validateValueIsAtMostMaximum(maximum));

export type ArithmeticExpression = Readonly<{ add?: readonly SemanticFieldPath[]; sub?: readonly SemanticFieldPath[] }>;
export type PolicyRule = Readonly<{ all_of?: readonly PolicyRule[]; any_of?: readonly PolicyRule[]; not?: PolicyRule; field?: SemanticFieldPath; expr?: ArithmeticExpression; op?: SemanticOperatorName; value?: SemanticValue }>;
export type PolicyCheck = Readonly<{ check_id: SemanticCheckIdentifier; rule: PolicyRule }>;
export type Mandate = Readonly<{ mandate_id: string; pdpp_version: string; principal_id: string; agent_id: string; issued_at: string; checks: readonly PolicyCheck[] }>;
export type PolicyEvaluationCheck = Readonly<{ check_id: SemanticCheckIdentifier; result: 'PASS' | 'FAIL'; evidence_ref: SemanticEvidence }>;

export const compareValuesAreEqual: SemanticPredicate = (left, right) => declareSemanticValidationResult(left === right);
export const compareLeftValueIsLessThanOrEqualToRightValue: SemanticPredicate = (left, right) => declareSemanticValidationResult(typeof left === 'number' && typeof right === 'number' && left <= right);
export const compareCollectionContainsValue: SemanticPredicate = (value, collection) => declareSemanticValidationResult(Array.isArray(collection) && typeof value === 'string' && collection.includes(value));
export const splitFieldPathIntoNamespaceAndKey = (path: SemanticFieldPath): readonly [string, string] => { const [namespace = '', key = ''] = String(path).split('.'); return [namespace, key]; };
export const resolveFieldPathFromSemanticContext = (context: SemanticContext, path: SemanticFieldPath): SemanticValue => { const [namespace, key] = splitFieldPathIntoNamespaceAndKey(path); return context[namespace]?.[key]; };
export const addResolvedFieldsFromSemanticContext = (context: SemanticContext, fields: readonly SemanticFieldPath[]): SemanticValue => fields.map(field => resolveFieldPathFromSemanticContext(context, field)).reduce((sum, value) => Number(sum) + Number(value), 0);
export const evaluateArithmeticExpression = (context: SemanticContext, expression: ArithmeticExpression): SemanticValue => expression.add ? addResolvedFieldsFromSemanticContext(context, expression.add) : undefined;
export const chooseSemanticPredicate = (operator: SemanticOperatorName): SemanticPredicate => ({ eq: compareValuesAreEqual, lte: compareLeftValueIsLessThanOrEqualToRightValue, in: compareCollectionContainsValue } as Record<string, SemanticPredicate>)[String(operator)] ?? compareValuesAreEqual;
export const evaluatePolicyRuleAgainstSemanticContext = (context: SemanticContext, rule: PolicyRule): readonly [SemanticValidationResult, SemanticEvidence] => { if (rule.all_of) return [declareSemanticValidationResult(rule.all_of.every(child => evaluatePolicyRuleAgainstSemanticContext(context, child)[0])), 'all_of children evaluated' as SemanticEvidence]; const actual = rule.expr ? evaluateArithmeticExpression(context, rule.expr) : resolveFieldPathFromSemanticContext(context, rule.field as SemanticFieldPath); return [chooseSemanticPredicate(rule.op as SemanticOperatorName)(actual, rule.value), 'semantic rule evaluated' as SemanticEvidence]; };
export const evaluateMandateAgainstTransactionAndInputs = (mandate: Mandate, transaction: Record<string, SemanticValue>, inputs: Record<string, SemanticValue>): readonly PolicyEvaluationCheck[] => { const context = { transaction, inputs }; return mandate.checks.map(check => { const [passed, evidence] = evaluatePolicyRuleAgainstSemanticContext(context, check.rule); return { check_id: check.check_id, result: passed ? 'PASS' : 'FAIL', evidence_ref: evidence }; }); };

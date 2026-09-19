export type AlertKind = 'record_lapsed' | 'record_restored';

export function alertMessage(kind: AlertKind) {
  if (kind === 'record_restored') {
    return {
      subject: 'FLD-AYA-01 / RECORD RESTORED',
      text:
        'F.C.C.D.B. / CONTINUED EXISTENCE REGISTER\n\n' +
        'The subject who designated you as witness has filed proof of continued existence. ' +
        'Their record is active again.\n\n' +
        'This is an automated personal-network notice from Are You Alive?.',
      html:
        '<p><strong>F.C.C.D.B. / CONTINUED EXISTENCE REGISTER</strong></p>' +
        '<p>The subject who designated you as witness has filed proof of continued existence. ' +
        'Their record is active again.</p>' +
        '<p>This is an automated personal-network notice from Are You Alive?.</p>',
    };
  }

  return {
    subject: 'FLD-AYA-01 / RECORD LAPSED',
    text:
      'F.C.C.D.B. / CONTINUED EXISTENCE REGISTER\n\n' +
      'The subject who designated you as witness has not filed proof of continued existence ' +
      'within the 39-hour filing window and witness grace period.\n\n' +
      'This is an automated personal-network notice, not an emergency-services alert. ' +
      'Use your own judgment about contacting the subject or someone who knows them.\n\n' +
      'FLD-AYA-01',
    html:
      '<p><strong>F.C.C.D.B. / CONTINUED EXISTENCE REGISTER</strong></p>' +
      '<p>The subject who designated you as witness has not filed proof of continued existence ' +
      'within the 39-hour filing window and witness grace period.</p>' +
      '<p><strong>This is an automated personal-network notice, not an emergency-services alert.</strong> ' +
      'Use your own judgment about contacting the subject or someone who knows them.</p>' +
      '<p>FLD-AYA-01</p>',
  };
}

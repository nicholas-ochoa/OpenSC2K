import { remote } from 'electron';

export async function messageBox(
  title: string,
  message: string,
  type: string = 'info',
  buttons: string[] = ['Ok', 'Cancel'],
  detail?: string
): Promise<any> {
  const dialog = remote.dialog;

  const options: any = {
    type,
    buttons,
    title,
    message,
    detail,
    normalizeAccessKeys: true,
  };

  const result: any = await dialog.showMessageBox(options);

  return {
    buttonClicked: buttons[result.response],
    checkboxChecked: result.checkboxChecked,
  };
}

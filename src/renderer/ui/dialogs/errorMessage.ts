import { messageBox } from './messageBox';

export async function errorMessage(
  message: string,
  detail: string,
  title: string = 'Error'
): Promise<void> {
  await messageBox(title, message, 'error', ['Ok'], detail);
}

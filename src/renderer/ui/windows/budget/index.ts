import { ipcRenderer } from 'electron';

export async function budget(): Promise<void> {
  try {
    await ipcRenderer.invoke('openBudgetWindow');
  } catch (e) {
    console.error(e);
  }
}

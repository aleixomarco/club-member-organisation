/* Typen zu mannschaften.mjs - reines JavaScript, damit die Tests es direkt
   mit "node --test" laden koennen. */

export interface Mitglied {
  team?: string | null;
  teams?: readonly string[] | null;
  playerTeams?: readonly string[] | null;
  trainerTeams?: readonly string[] | null;
  captainTeams?: readonly string[] | null;
  managedTeams?: readonly string[] | null;
  managedTeam?: string | null;
  roles?: readonly string[] | null;
}

export function memberPlayerTeams(member: Mitglied | null | undefined): string[];
export function memberTrainerTeams(member: Mitglied | null | undefined): string[];
export function memberCaptainTeams(member: Mitglied | null | undefined): string[];
export function memberManagedTeams(member: Mitglied | null | undefined): string[];
export function memberAllTeams(member: Mitglied | null | undefined): string[];
export function memberInTeam(member: Mitglied | null | undefined, teamName: unknown): boolean;
export function hoechstesTeam<T extends { name?: string | null }>(liste: readonly T[] | null | undefined): T | null;

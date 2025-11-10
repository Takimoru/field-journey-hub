import { useAuth } from '@/hooks/useAuth';
import { useUserRole } from '@/hooks/useUserRole';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Loader2, LogOut, Users, Calendar, ClipboardList, UserCircle } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

const Index = () => {
  const { user, signOut } = useAuth();
  const { roles, loading } = useUserRole();
  const navigate = useNavigate();

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-muted/30">
      <header className="border-b bg-background">
        <div className="container mx-auto flex items-center justify-between px-4 py-4">
          <h1 className="text-2xl font-bold">Field Study Manager</h1>
          <div className="flex items-center gap-4">
            <div className="text-sm">
              <p className="font-medium">{user?.email}</p>
              <p className="text-muted-foreground">
                {roles.includes('admin') ? 'Admin' :
                 roles.includes('supervisor') ? 'Supervisor' :
                 roles.includes('team_leader') ? 'Team Leader' :
                 'Team Member'}
              </p>
            </div>
            <Button variant="outline" size="sm" onClick={() => signOut()}>
              <LogOut className="mr-2 h-4 w-4" />
              Sign Out
            </Button>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8">
        <div className="mb-8">
          <h2 className="text-3xl font-bold">Dashboard</h2>
          <p className="text-muted-foreground">
            Welcome to the Field Study Management System
          </p>
        </div>

        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {roles.includes('admin') && (
            <>
              <Card className="cursor-pointer transition-shadow hover:shadow-lg">
                <CardHeader>
                  <Calendar className="mb-2 h-8 w-8 text-primary" />
                  <CardTitle>Programs</CardTitle>
                  <CardDescription>Create and manage field study programs</CardDescription>
                </CardHeader>
              </Card>

              <Card className="cursor-pointer transition-shadow hover:shadow-lg">
                <CardHeader>
                  <Users className="mb-2 h-8 w-8 text-primary" />
                  <CardTitle>Teams</CardTitle>
                  <CardDescription>Organize teams and assign supervisors</CardDescription>
                </CardHeader>
              </Card>

              <Card className="cursor-pointer transition-shadow hover:shadow-lg">
                <CardHeader>
                  <UserCircle className="mb-2 h-8 w-8 text-primary" />
                  <CardTitle>User Management</CardTitle>
                  <CardDescription>Manage user roles and permissions</CardDescription>
                </CardHeader>
              </Card>
            </>
          )}

          {roles.includes('supervisor') && (
            <Card className="cursor-pointer transition-shadow hover:shadow-lg">
              <CardHeader>
                <ClipboardList className="mb-2 h-8 w-8 text-primary" />
                <CardTitle>Review Reports</CardTitle>
                <CardDescription>Review and provide feedback on weekly reports</CardDescription>
              </CardHeader>
            </Card>
          )}

          {(roles.includes('team_leader') || roles.includes('team_member')) && (
            <>
              <Card className="cursor-pointer transition-shadow hover:shadow-lg">
                <CardHeader>
                  <ClipboardList className="mb-2 h-8 w-8 text-primary" />
                  <CardTitle>Daily Check-in</CardTitle>
                  <CardDescription>Record your daily attendance</CardDescription>
                </CardHeader>
              </Card>

              <Card className="cursor-pointer transition-shadow hover:shadow-lg">
                <CardHeader>
                  <Calendar className="mb-2 h-8 w-8 text-primary" />
                  <CardTitle>Weekly Tasks</CardTitle>
                  <CardDescription>View and manage your weekly assignments</CardDescription>
                </CardHeader>
              </Card>

              <Card className="cursor-pointer transition-shadow hover:shadow-lg">
                <CardHeader>
                  <ClipboardList className="mb-2 h-8 w-8 text-primary" />
                  <CardTitle>Team Reports</CardTitle>
                  <CardDescription>Submit and view weekly progress reports</CardDescription>
                </CardHeader>
              </Card>
            </>
          )}
        </div>

        {roles.length === 0 && (
          <Card>
            <CardHeader>
              <CardTitle>Welcome!</CardTitle>
              <CardDescription>
                Your account has been created. Please wait for an administrator to assign you a role.
              </CardDescription>
            </CardHeader>
          </Card>
        )}
      </main>
    </div>
  );
};

export default Index;

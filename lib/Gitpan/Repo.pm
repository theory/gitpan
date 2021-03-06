use MooseX::Declare;

class Gitpan::Repo {
    use perl5i::2;
    use Path::Class;
    use Gitpan::Types qw(Distname AbsDir);
    use MooseX::AlwaysCoerce;
    use Gitpan::Github;

    use overload
      q[""]     => method { return $self->distname },
      fallback  => 1;

    has distname        => 
      isa       => Distname,
      is        => 'ro',
      required  => 1,
    ;

    has cwd     =>
      isa       => AbsDir,
      is        => 'ro',
      required  => 1,
      default   => method {
          return dir()->absolute;
      },
      documentation => "The current working directory at time of object initialization";

    has directory       =>
      isa       => AbsDir,
      is        => 'ro',
      required  => 1,
      lazy      => 1,
      default     => method {
          $self->_make_absolute($self->distname);
      },
      initializer => sub {
          my($self, $value, $setter) = @_;
          $setter->( $self->_make_absolute($value) );
      };

    # Make sure the directory is absolute from the original cwd
    method _make_absolute($dir?) {
        $dir //= $self->distname;

        $dir = dir($dir);
        return $dir if $dir->is_absolute;
        return $self->cwd->subdir($self->distname);        
    }


    has git     =>
      isa       => "Gitpan::Git",
      is        => 'rw',
      required  => 1,
      lazy      => 1,
      coerce    => 0,
      default   => method {
          require Gitpan::Git;
          return Gitpan::Git->create( init => $self->directory);
      };

    has github  =>
      isa       => "Gitpan::Github|HashRef",
      is        => 'rw',
      lazy      => 1,
      trigger   => sub {        # trigger doesn't take a method
          my($self, $new, $old) = @_;

          return $new if $new->isa("Gitpan::Github");
          $self->github( $self->_new_github($new) );
      },
      default   => method {
          return $self->_new_github;
      };

    method _new_github(HashRef $args = {}) {
        return Gitpan::Github->new(
            repo      => $self->distname,
            %$args,
        );
    }

    method exists_on_github() {
        # Optimization, asking github is expensive
        return 1 if $self->git->remote("origin") =~ /github.com/;
        return $self->github->exists_on_github();
    }

    method note(@args) {
        # no op for now
    }
}
